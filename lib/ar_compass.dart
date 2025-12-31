import 'package:flutter/services.dart';

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

  const CompassEvent._({
    this.heading,
    this.headingForCameraMode,
    this.accuracy,
  });

  /// Creates a CompassEvent from raw platform data.
  ///
  /// Uses Dart 3 pattern matching for safe parsing.
  factory CompassEvent.fromList(List<double>? data) {
    return switch (data) {
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
  }) = CompassEvent._;

  /// Checks if this event has valid heading data.
  bool get isValid => heading != null && accuracy != null;

  /// Checks if the compass needs calibration (accuracy > 20 degrees).
  bool get needsCalibration => accuracy != null && accuracy! > 20;

  @override
  String toString() => 'CompassEvent('
      'heading: $heading, '
      'headingForCameraMode: $headingForCameraMode, '
      'accuracy: $accuracy)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompassEvent &&
          runtimeType == other.runtimeType &&
          heading == other.heading &&
          headingForCameraMode == other.headingForCameraMode &&
          accuracy == other.accuracy;

  @override
  int get hashCode => Object.hash(heading, headingForCameraMode, accuracy);
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
