import 'package:flutter/services.dart';

/// Calibration status for the compass sensor.
enum CompassCalibrationStatus {
  /// Sensor is unreliable, calibration required.
  unreliable(0),

  /// Low accuracy, calibration recommended.
  low(1),

  /// Medium accuracy, acceptable.
  medium(2),

  /// High accuracy, well calibrated.
  high(3);

  const CompassCalibrationStatus(this.value);
  final int value;

  /// Creates a CalibrationStatus from an integer value.
  static CompassCalibrationStatus fromValue(int? value) {
    return switch (value) {
      3 => CompassCalibrationStatus.high,
      2 => CompassCalibrationStatus.medium,
      1 => CompassCalibrationStatus.low,
      _ => CompassCalibrationStatus.unreliable,
    };
  }

  /// Returns true if calibration is needed (unreliable or low accuracy).
  bool get needsCalibration =>
      this == CompassCalibrationStatus.unreliable ||
      this == CompassCalibrationStatus.low;
}

/// Represents a compass event with heading information.
///
/// Uses Dart 3 records pattern for data parsing.
final class CompassEvent {
  /// The heading, in degrees, of the device around its Z axis,
  /// or where the top of the device is pointing.
  final double? heading;

  /// The heading, in degrees, of the device around its X axis,
  /// or where the back of the device is pointing.
  final double? headingForCameraMode;

  /// The deviation error, in degrees, plus or minus from the heading.
  /// NOTE: for iOS this is computed by the platform and is reliable. For
  /// Android several values are hard-coded, and the true error could be more
  /// or less than the value here.
  final double? accuracy;

  /// The calibration status of the compass sensor.
  /// Only available on Android. On iOS, this will be null.
  final CompassCalibrationStatus? calibrationStatus;

  const CompassEvent._({
    this.heading,
    this.headingForCameraMode,
    this.accuracy,
    this.calibrationStatus,
  });

  /// Creates a CompassEvent from raw platform data.
  ///
  /// Uses Dart 3 pattern matching for safe parsing.
  factory CompassEvent.fromList(List<double>? data) {
    return switch (data) {
      // Android format with calibration status (4 values)
      [final h, final hCam, final acc, final calibration] => CompassEvent._(
          heading: h,
          headingForCameraMode: hCam,
          accuracy: acc == -1 ? null : acc,
          calibrationStatus:
              CompassCalibrationStatus.fromValue(calibration.toInt()),
        ),
      // iOS format without calibration status (3 values)
      [final h, final hCam, final acc] => CompassEvent._(
          heading: h,
          headingForCameraMode: hCam,
          accuracy: acc == -1 ? null : acc,
        ),
      _ => const CompassEvent._(),
    };
  }

  /// Creates a CompassEvent with specific values.
  const factory CompassEvent({
    double? heading,
    double? headingForCameraMode,
    double? accuracy,
    CompassCalibrationStatus? calibrationStatus,
  }) = CompassEvent._;

  /// Checks if this event has valid heading data.
  bool get isValid => heading != null && accuracy != null;

  /// Checks if the compass needs calibration (accuracy > 20 degrees).
  bool get needsCalibration => accuracy != null && accuracy! > 20;

  @override
  String toString() => 'CompassEvent('
      'heading: $heading, '
      'headingForCameraMode: $headingForCameraMode, '
      'accuracy: $accuracy, '
      'calibrationStatus: $calibrationStatus)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompassEvent &&
          runtimeType == other.runtimeType &&
          heading == other.heading &&
          headingForCameraMode == other.headingForCameraMode &&
          accuracy == other.accuracy &&
          calibrationStatus == other.calibrationStatus;

  @override
  int get hashCode =>
      Object.hash(heading, headingForCameraMode, accuracy, calibrationStatus);
}

/// Singleton class managing compass heading stream from native platform.
final class ArCompass {
  static final ArCompass _instance = ArCompass._();

  factory ArCompass() => _instance;

  ArCompass._();

  static const EventChannel _compassChannel =
      EventChannel('pie/ar_view_location');

  static Stream<CompassEvent>? _stream;

  /// Provides a [Stream] of compass events that can be listened to.
  static Stream<CompassEvent>? get events {
    _stream ??= _compassChannel.receiveBroadcastStream().map(
          (dynamic data) => CompassEvent.fromList(
            (data as List<dynamic>?)?.cast<double>(),
          ),
        );
    return _stream;
  }

  /// Resets the stream (useful for testing or reconnection).
  static void reset() {
    _stream = null;
  }
}
