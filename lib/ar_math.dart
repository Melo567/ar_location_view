import 'dart:math';

import 'package:ar_location_view/ar_extension.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:vector_math/vector_math_64.dart';

/// Utility class for AR-related mathematical calculations.
///
/// Uses Dart 3 features including switch expressions and extension types.
final class ArMath {
  // Private constructor to prevent instantiation
  ArMath._();

  /// Normalizes degree to 0-360 range.
  static double normalizeDegree(double degree) {
    var degreeNormalized = 360 % degree;
    if (degreeNormalized < 0) {
      degreeNormalized = 360 + degreeNormalized;
    }
    return degreeNormalized;
  }

  /// Normalizes degree to -180...180 range.
  static double normalizeDegree2(double degree) {
    final degreeNormalized = degree % 360;
    return switch (degreeNormalized) {
      > 180 => degreeNormalized - 360,
      < -180 => degreeNormalized + 360,
      _ => degreeNormalized,
    };
  }

  /// Calculates the shortest angle difference between two angles.
  static double deltaAngle(double angle1, double angle2) {
    final delta = angle1 - angle2;
    return switch (delta) {
      > 180 => delta - 360,
      < -180 => delta + 360,
      _ => delta,
    };
  }

  /// Applies exponential filter for smooth value transitions.
  ///
  /// Handles circular values (e.g., angles that wrap at 360).
  static double exponentialFilter(
    double newValue,
    double previousValue,
    double filterFactor, {
    bool isCircular = false,
  }) {
    var adjustedNewValue = newValue;

    if (isCircular && (newValue - previousValue).abs() > 180) {
      adjustedNewValue = switch ((previousValue, newValue)) {
        (< 180, > 180) => newValue - 360,
        (> 180, < 180) => newValue + 360,
        _ => newValue,
      };
    }

    return (adjustedNewValue * filterFactor) +
        (previousValue * (1.0 - filterFactor));
  }

  /// Calculates bearing from user location to target location.
  static double bearingFromUserToLocation(
    Position userLocation,
    Position location, {
    bool approximate = false,
  }) {
    return approximate
        ? approximateBearingBetween(userLocation, location)
        : bearingBetween(userLocation, location);
  }

  /// Calculates precise bearing between two positions using Haversine formula.
  static double bearingBetween(Position startLocation, Position endLocation) {
    final lat1 = startLocation.latitude.toRadians;
    final lon1 = startLocation.longitude.toRadians;
    final lat2 = endLocation.latitude.toRadians;
    final lon2 = endLocation.longitude.toRadians;

    final dLon = lon2 - lon1;
    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    var bearing = atan2(y, x).toDegrees;
    if (bearing < 0) {
      bearing += 360;
    }

    return bearing;
  }

  /// Calculates approximate bearing (faster but less accurate).
  static double approximateBearingBetween(
    Position startLocation,
    Position endLocation,
  ) {
    const latLongFactor = 1.33975031663;

    final latitudeDistance =
        startLocation.latitude - endLocation.latitude;
    final longitudeDistance =
        startLocation.longitude - endLocation.longitude;

    final bearing = atan2(
      longitudeDistance,
      latitudeDistance * latLongFactor.toDegrees,
    ).toDegrees;

    return bearing + 180.0;
  }

  /// Calculates device pitch from gravity vector and orientation.
  ///
  /// Uses Dart 3 switch expression for cleaner pattern matching.
  static double calculatePitch({
    required Vector3 gravity,
    required NativeDeviceOrientation orientation,
  }) {
    final rawPitch = switch (orientation) {
      NativeDeviceOrientation.portraitDown => atan2(-gravity.y, gravity.z),
      NativeDeviceOrientation.landscapeLeft => atan2(gravity.x, gravity.z),
      NativeDeviceOrientation.landscapeRight => atan2(-gravity.x, gravity.z),
      _ => atan2(gravity.y, gravity.z),
    };

    var pitch = rawPitch.toDegrees + 90;
    if (pitch > 180) {
      pitch -= 360;
    }

    return pitch;
  }
}
