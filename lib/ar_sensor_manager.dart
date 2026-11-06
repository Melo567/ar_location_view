import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ar_location_view.dart';
import 'ar_low_pass_filter.dart';

/// Platform streams and permission calls used by [ArSensorManager].
///
/// The defaults talk to the device. Replace them, e.g. with
/// [StreamController]s, to test code using [ArSensorManager] without
/// hardware.
class ArSensorBackend {
  const ArSensorBackend({
    this.accelerometer = _accelerometer,
    this.compass = _compass,
    this.position = Geolocator.getPositionStream,
    this.locationPermissionStatus = _locationPermissionStatus,
    this.requestLocationPermission = _requestLocationPermission,
  });

  /// Raw accelerometer samples, only used for the pitch until the compass
  /// provides a full rotation matrix.
  final Stream<AccelerometerEvent> Function() accelerometer;

  /// Heading and attitude from the plugin's native side, null when
  /// unavailable.
  final Stream<CompassEvent>? Function() compass;

  final Stream<Position> Function({LocationSettings? locationSettings})
  position;

  final Future<PermissionStatus> Function() locationPermissionStatus;

  /// Prompts the user for the location permission.
  final Future<PermissionStatus> Function() requestLocationPermission;

  // The default sampling period (200 ms) makes the pitch visibly jerky.
  static Stream<AccelerometerEvent> _accelerometer() =>
      accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);

  static Stream<CompassEvent>? _compass() => ArCompass.events;

  static Future<PermissionStatus> _locationPermissionStatus() =>
      Permission.location.status;

  static Future<PermissionStatus> _requestLocationPermission() =>
      Permission.location.request();
}

class ArSensorManager implements ArSensorSource {
  /// Pass a null filter to use the raw sensor values.
  ///
  /// [locationSettings] configures the position stream (accuracy, distance
  /// filter...), see [Geolocator.getPositionStream].
  ArSensorManager({
    AttitudeFilter? attitudeFilter,
    HeadingFilter? headingFilter,
    LocationFilter? locationFilter,
    bool smoothAttitude = true,
    bool smoothLocation = true,
    this.locationSettings,
    this.backend = const ArSensorBackend(),
  }) : _attitudeFilter = smoothAttitude
           ? (attitudeFilter ?? AttitudeFilter())
           : null,
       _headingFilter = smoothAttitude
           ? (headingFilter ?? HeadingFilter())
           : null,
       _locationFilter = smoothLocation
           ? (locationFilter ?? LocationFilter())
           : null;

  final LocationSettings? locationSettings;

  final ArSensorBackend backend;

  final AttitudeFilter? _attitudeFilter;
  final HeadingFilter? _headingFilter;
  final LocationFilter? _locationFilter;

  /// Monotonic clock for the time-based filters.
  final Stopwatch _clock = Stopwatch()..start();

  StreamSubscription<AccelerometerEvent>? _accelerationStream;
  StreamSubscription<CompassEvent>? _headingStream;
  StreamSubscription<Position>? _positionSubscription;

  /// UI orientation, received with the compass events.
  DeviceOrientation _orientation = DeviceOrientation.portraitUp;

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
  /// sample (50 Hz, see [ArSensorBackend.accelerometer]): alpha 0.04 gives
  /// a time constant of ~0.5 s, which also filters out the user's own
  /// acceleration so the raw accelerometer approximates gravity.
  final LowPassFilter _pitchFilter = LowPassFilter(alpha: 0.04);

  bool _initialized = false;
  bool _disposed = false;
  bool _paused = false;
  bool _permissionGranted = false;
  bool _checkingPermission = false;

  /// Idempotent: calling it again (e.g. from several views sharing this
  /// manager) does not re-subscribe to the sensors.
  @override
  void init() {
    if (_initialized || _disposed) return;
    _initialized = true;
    _checkLocationPermission(request: true);
  }

  /// Stops the sensors and the location updates, e.g. while the app is in
  /// background, without closing [arSensor]. [ArView] does it for the
  /// manager it creates; call it yourself on a manager you provide.
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    _stopSensors();
  }

  /// Restarts what [pause] stopped. When the location permission was
  /// denied, checks it again (without prompting): the user may have
  /// granted it from the system settings meanwhile.
  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    if (_permissionGranted) {
      // Samples from before the pause would be blended with the new ones.
      _resetFilters();
      _startSensors();
    } else if (_initialized && !_checkingPermission) {
      _checkLocationPermission(request: false);
    }
  }

  void _startSensors() {
    _accelerationStream = backend.accelerometer().listen((
      AccelerometerEvent event,
    ) {
      _updatePitch(Vector3(event.x, event.y, event.z));
      _emit();
    });
    _headingStream = backend.compass()?.listen(_onCompass);

    _positionSubscription = backend
        .position(locationSettings: locationSettings)
        .listen(
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
  }

  void _stopSensors() {
    _accelerationStream?.cancel();
    _accelerationStream = null;
    _headingStream?.cancel();
    _headingStream = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _resetFilters() {
    _attitudeFilter?.reset();
    _headingFilter?.reset();
    _locationFilter?.reset();
    _pitchFilter.reset();
  }

  void _onCompass(CompassEvent event) {
    // Before the pitch fallback below reads it.
    final orientation = event.orientation;
    if (orientation != null) _orientation = orientation;
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

  /// The permission prompt can stay open for a long time: [dispose] or
  /// [pause] may run meanwhile, so the sensors must not be started once it
  /// resolves. Without [request], only checks the permission and reports
  /// nothing when it is still missing.
  Future<void> _checkLocationPermission({required bool request}) async {
    _checkingPermission = true;
    try {
      var status = await backend.locationPermissionStatus();
      if (request && !status.isGranted && !status.isPermanentlyDenied) {
        status = await backend.requestLocationPermission();
      }
      if (_disposed) return;
      if (status.isGranted) {
        _permissionGranted = true;
        if (!_paused) _startSensors();
      } else if (!request) {
        return;
      } else if (status.isPermanentlyDenied) {
        _addError(ArSensorErrorType.permissionPermanentlyDenied);
      } else {
        _addError(ArSensorErrorType.permissionDenied);
      }
    } catch (error) {
      if (request) _addError(ArSensorErrorType.unknown, error);
    } finally {
      _checkingPermission = false;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _arSensorController.close();
    _stopSensors();
  }
}
