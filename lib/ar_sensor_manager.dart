import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ar_location_view.dart';

class ArSensorManager {
  static final ArSensorManager instance = ArSensorManager._internal();

  ArSensorManager._internal();

  StreamSubscription<AccelerometerEvent>? _accelerationStream;
  StreamSubscription<CompassEvent>? _headingStream;
  StreamSubscription<UserAccelerometerEvent>? _userAccelerationStream;
  StreamSubscription<Position>? _positionSubscription;
  final NativeDeviceOrientationCommunicator _deviceOrientationCommunicator =
      NativeDeviceOrientationCommunicator();
  Stream<NativeDeviceOrientation>? _orientationStream;
  StreamSubscription<NativeDeviceOrientation>? _orientationStreamSubscription;
  NativeDeviceOrientation _orientation = NativeDeviceOrientation.portraitUp;

  Vector3 _accelerometer = Vector3.zero();
  Vector3 _userAccelerometer = Vector3.zero();

  Position? _position;

  double _heading = 0.0;
  double _compassAccuracy = 0.0;

  late StreamController<ArSensor> _arSensorController;

  List<double> pitchHistory = [];

  void init() {
    _arSensorController = StreamController();
    _checkLocationPermission();
  }

  void _initialisation() {
    _accelerationStream =
        accelerometerEvents.listen((AccelerometerEvent event) {
      _accelerometer = Vector3(event.x, event.y, event.z);
      _calculateSensor();
    });
    _userAccelerationStream =
        userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      _userAccelerometer = Vector3(event.x, event.y, event.z);
      _calculateSensor();
    });
    _headingStream = ArCompass.events?.listen((CompassEvent event) {
      if (event.heading != null && event.accuracy != null) {
        _heading = event.heading!;
        _compassAccuracy = event.accuracy!;
        _calculateSensor();
      }
    });

    _positionSubscription =
        Geolocator.getPositionStream().listen((Position position) {
      _position = position;
      _calculateSensor();
    });

    _orientationStream =
        _deviceOrientationCommunicator.onOrientationChanged(useSensor: true);
    _orientationStreamSubscription = _orientationStream?.listen((event) {
      _orientation = event;
    });
  }

  void _calculateSensor() {
    const coef = -0.1;
    final x = coef * (_accelerometer.x - _userAccelerometer.x);
    final y = coef * (_accelerometer.y - _userAccelerometer.y);
    final z = coef * (_accelerometer.z - _userAccelerometer.z);
    final Vector3 gravity = Vector3(x, y, z);
    final double pitch = ArMath.calculatePitch(
      gravity: gravity,
      orientation: _orientation,
    );

    pitchHistory.add(pitch);

    const serieLength = 100;
    const alpha = 0.009;
    if (pitchHistory.length > serieLength) {
      pitchHistory = pitchHistory.sublist(pitchHistory.length - serieLength);
    }

    final arSensor = ArSensor(
      heading: _heading,
      pitch: _filterExponential(pitchHistory, alpha),
      location: _position,
      orientation: _orientation,
      compassAccuracy: _compassAccuracy,
    );
    _arSensorController.add(arSensor);
  }

  Stream<ArSensor> get arSensor => _arSensorController.stream;

  Future<void> _checkLocationPermission() async {
    bool isLocationGranted = await Permission.location.isGranted;
    if (!isLocationGranted) {
      await Permission.location.request();
      isLocationGranted = await Permission.location.isGranted;
      if (isLocationGranted) {
        _initialisation();
      }
    } else {
      _initialisation();
    }
  }

  void dispose() {
    _arSensorController.close();
    _accelerationStream?.cancel();
    _userAccelerationStream?.cancel();
    _positionSubscription?.cancel();
    _orientationStreamSubscription?.cancel();
    _headingStream?.cancel();
  }

  double _filterExponential(List<double> numbers, double alpha) {
    final coef = 1 - alpha;
    final temps = numbers.reversed.toList();
    double sum = 0.0;
    for (int i = 0; i < temps.length; i++) {
      sum += pow(coef, i) * temps[i];
    }
    return alpha * sum;
  }
}
