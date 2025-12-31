import 'package:pigeon/pigeon.dart';

/// Configuration for Pigeon code generation.
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/ar_sensor_api.g.dart',
  dartOptions: DartOptions(),
  kotlinOut:
      'android/src/main/kotlin/com/pie/technology/ar/location/view/ar_location_view/ArSensorApi.kt',
  kotlinOptions: KotlinOptions(
    package: 'com.pie.technology.ar.location.view.ar_location_view',
  ),
  swiftOut: 'ios/Classes/ArSensorApi.swift',
  swiftOptions: SwiftOptions(),
))

/// Data class representing sensor data from native platform.
class SensorData {
  SensorData({
    required this.heading,
    required this.headingForCameraMode,
    required this.accuracy,
    this.timestamp,
  });

  /// Device heading in degrees (0-360).
  final double heading;

  /// Heading adjusted for camera mode.
  final double headingForCameraMode;

  /// Accuracy of the heading in degrees.
  /// -1 indicates invalid/unavailable.
  final double accuracy;

  /// Timestamp in milliseconds since epoch.
  final int? timestamp;
}

/// Configuration for sensor updates.
class SensorConfig {
  SensorConfig({
    this.updateIntervalMs = 33,
    this.useTrueNorth = true,
  });

  /// Update interval in milliseconds.
  final int updateIntervalMs;

  /// Whether to use true north (vs magnetic north).
  final bool useTrueNorth;
}

/// Result of permission request.
class PermissionResult {
  PermissionResult({
    required this.granted,
    this.message,
  });

  /// Whether permission was granted.
  final bool granted;

  /// Optional message about the result.
  final String? message;
}

/// Calibration status for compass.
enum CalibrationStatus {
  /// Calibration is not needed.
  notNeeded,

  /// Calibration is recommended.
  recommended,

  /// Calibration is required for accurate readings.
  required,
}

/// Host API - methods called from Dart to native.
@HostApi()
abstract class ArSensorHostApi {
  /// Starts sensor updates with the given configuration.
  void startSensorUpdates(SensorConfig config);

  /// Stops sensor updates.
  void stopSensorUpdates();

  /// Checks if sensors are available on this device.
  bool areSensorsAvailable();

  /// Gets the current calibration status.
  CalibrationStatus getCalibrationStatus();

  /// Requests location permission.
  @async
  PermissionResult requestLocationPermission();
}

/// Flutter API - methods called from native to Dart.
@FlutterApi()
abstract class ArSensorFlutterApi {
  /// Called when new sensor data is available.
  void onSensorUpdate(SensorData data);

  /// Called when calibration is needed.
  void onCalibrationNeeded(CalibrationStatus status);

  /// Called when an error occurs.
  void onError(String message);
}
