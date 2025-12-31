import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

/// Data class representing sensor readings for AR positioning.
///
/// Uses Dart 3 features for immutability and pattern matching support.
final class ArSensor {
  final double heading;
  final double pitch;
  final Position? location;
  final NativeDeviceOrientation orientation;
  final double compassAccuracy;

  const ArSensor({
    required this.heading,
    required this.pitch,
    required this.orientation,
    required this.compassAccuracy,
    this.location,
  });

  /// Creates a copy with optionally updated values.
  ArSensor copyWith({
    double? heading,
    double? pitch,
    Position? location,
    NativeDeviceOrientation? orientation,
    double? compassAccuracy,
  }) {
    return ArSensor(
      heading: heading ?? this.heading,
      pitch: pitch ?? this.pitch,
      location: location ?? this.location,
      orientation: orientation ?? this.orientation,
      compassAccuracy: compassAccuracy ?? this.compassAccuracy,
    );
  }

  /// Checks if the sensor has valid location data.
  bool get hasValidLocation => location != null;

  /// Checks if the compass has good accuracy (< 15 degrees error).
  bool get hasGoodAccuracy => compassAccuracy >= 0 && compassAccuracy < 15;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArSensor &&
          runtimeType == other.runtimeType &&
          heading == other.heading &&
          pitch == other.pitch &&
          location == other.location &&
          orientation == other.orientation &&
          compassAccuracy == other.compassAccuracy;

  @override
  int get hashCode => Object.hash(
        heading,
        pitch,
        location,
        orientation,
        compassAccuracy,
      );

  @override
  String toString() =>
      'ArSensor(heading: $heading, pitch: $pitch, location: $location, '
      'orientation: $orientation, compassAccuracy: $compassAccuracy)';
}
