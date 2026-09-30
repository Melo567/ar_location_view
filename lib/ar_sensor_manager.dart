import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ar_location_view.dart';
import 'ar_low_pass_filter.dart';

class ArSensorManager implements ArSensorSource {
  /// Pass a null filter to use the raw sensor values.
  ArSensorManager({
    AttitudeFilter? attitudeFilter,
    HeadingFilter? headingFilter,
    LocationFilter? locationFilter,
    bool smoothAttitude = true,
    bool smoothLocation = true,
  })  : _attitudeFilter =
            smoothAttitude ? (attitudeFilter ?? AttitudeFilter()) : null,
        _headingFilter =
            smoothAttitude ? (headingFilter ?? HeadingFilter()) : null,
        _locationFilter =
            smoothLocation ? (locationFilter ?? LocationFilter()) : null;

  final AttitudeFilter? _attitudeFilter;
  final HeadingFilter? _headingFilter;
  final LocationFilter? _locationFilter;

  /// Monotonic clock for the time-based filters.
  final Stopwatch _clock = Stopwatch()..start();

  StreamSubscription<AccelerometerEvent>? _accelerationStream;
  StreamSubscription<CompassEvent>? _headingStream;
  StreamSubscription<Position>? _positionSubscription;
  final NativeDeviceOrientationCommunicator _deviceOrientationCommunicator =
      NativeDeviceOrientationCommunicator();
  Stream<NativeDeviceOrientation>? _orientationStream;
  StreamSubscription<NativeDeviceOrientation>? _orientationStreamSubscription;
  NativeDeviceOrientation _orientation = NativeDeviceOrientation.portraitUp;

  Position? _position;

  double _heading = 0.0;
  double _compassAccuracy = -1;
  double _pitch = 0.0;
  List<double>? _rotationMatrix;

  /// Broadcast so a single manager can feed several [ArView]s.
  final StreamController<ArSensor> _arSensorController =
      StreamController.broadcast();

  /// Fallback pitch source, only used until the platform provides a full
  /// rotation matrix (see [_onCompass]). Applied once per accelerometer
  /// sample (50 Hz, see [_initialisation]): alpha 0.04 gives a time constant
  /// of ~0.5 s, which also filters out the user's own acceleration so the
  /// raw accelerometer approximates gravity.
  final LowPassFilter _pitchFilter = LowPassFilter(alpha: 0.04);

  bool _initialized = false;
  bool _disposed = false;

  /// Idempotent: calling it again (e.g. from several views sharing this
  /// manager) does not re-subscribe to the sensors.
  @override
  void init() {
    if (_initialized || _disposed) return;
    _initialized = true;
    _checkLocationPermission();
  }

  void _initialisation() {
    // The default sampling period (200 ms) makes the pitch visibly jerky.
    _accelerationStream = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((AccelerometerEvent event) {
      _updatePitch(Vector3(event.x, event.y, event.z));
      _emit();
    });
    _headingStream = ArCompass.events?.listen(_onCompass);

    _positionSubscription = Geolocator.getPositionStream().listen(
      (Position position) {
        _position = _locationFilter?.add(position) ?? position;
        _emit();
      },
      onError: (Object error) => _addError(
        error is LocationServiceDisabledException
            ? ArSensorErrorType.locationServiceDisabled
            : ArSensorErrorType.unknown,
        error,
      ),
    );

    _orientationStream =
        _deviceOrientationCommunicator.onOrientationChanged(useSensor: true);
    _orientationStreamSubscription = _orientationStream?.listen((event) {
      _orientation = event;
    });
  }

  void _onCompass(CompassEvent event) {
    // A null accuracy means "unknown/uncalibrated", not "no heading":
    // dropping those events froze the heading until calibration.
    _compassAccuracy = event.accuracy ?? -1;
    final rotationMatrix = event.rotationMatrix;
    if (rotationMatrix != null) {
      // The attitude carries heading, pitch and roll from the same fused
      // sample: the accelerometer fallback is no longer needed.
      final smoothed =
          _attitudeFilter?.add(rotationMatrix, _now) ?? rotationMatrix;
      _rotationMatrix = smoothed;
      _heading = ArRotation.heading(smoothed);
      _pitch = ArRotation.pitch(smoothed);
      _accelerationStream?.cancel();
      _accelerationStream = null;
    } else {
      final heading = event.heading;
      if (heading == null) return;
      _heading = _headingFilter?.add(heading, _now) ?? heading;
    }
    _emit();
  }

  double get _now => _clock.elapsedMicroseconds / 1e6;

  /// Only accelerometer samples feed the pitch filter, so its smoothing does
  /// not depend on how often the compass or GPS happen to fire.
  void _updatePitch(Vector3 acceleration) {
    // calculatePitch expects the gravity vector pointing down (-g).
    final gravity = acceleration * -0.1;
    final pitch = ArMath.calculatePitch(
      gravity: gravity,
      orientation: _orientation,
    );
    _pitch = _pitchFilter.add(pitch);
  }

  void _emit() {
    if (_disposed) return;
    final arSensor = ArSensor(
      heading: _heading,
      pitch: _pitch,
      location: _position,
      orientation: _orientation,
      compassAccuracy: _compassAccuracy,
      rotationMatrix: _rotationMatrix,
    );
    _arSensorController.add(arSensor);
  }

  void _addError(ArSensorErrorType type, [Object? cause]) {
    if (_disposed) return;
    _arSensorController.addError(ArSensorException(type, cause: cause));
  }

  @override
  Stream<ArSensor> get arSensor => _arSensorController.stream;

  /// The permission prompt can stay open for a long time: [dispose] may run
  /// meanwhile, so the sensors must not be started once it resolves.
  Future<void> _checkLocationPermission() async {
    try {
      var status = await Permission.location.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        status = await Permission.location.request();
      }
      if (_disposed) return;
      if (status.isGranted) {
        _initialisation();
      } else if (status.isPermanentlyDenied) {
        _addError(ArSensorErrorType.permissionPermanentlyDenied);
      } else {
        _addError(ArSensorErrorType.permissionDenied);
      }
    } catch (error) {
      _addError(ArSensorErrorType.unknown, error);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _arSensorController.close();
    _accelerationStream?.cancel();
    _positionSubscription?.cancel();
    _orientationStreamSubscription?.cancel();
    _headingStream?.cancel();
  }
}
