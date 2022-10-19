import 'dart:math';

import 'package:ar_location_view/ar_extension.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:vector_math/vector_math_64.dart';

class ArMath {
  ///Normalizes degree to 0-360
  static double normalizeDegree(double degree) {
    var degreeNormalized = 360 % degree;
    if (degreeNormalized < 0) {
      degreeNormalized = 360 + degreeNormalized;
    }
    return degreeNormalized;
  }

  ///Normalizes degree to 0...180, 0...-180
  static double normalizeDegree2(double degree) {
    var degreeNormalized = degree % 360;
    if (degreeNormalized > 180) {
      degreeNormalized -= 360;
    } else if (degreeNormalized < -180) {
      degreeNormalized += 360;
    }

    return degreeNormalized;
  }

  static double deltaAngle(double angle1, double angle2) {
    var deltaAngle = angle1 - angle2;
    if (deltaAngle > 180) {
      deltaAngle -= 360;
    } else if (deltaAngle < -180) {
      deltaAngle += 360;
    }
    return deltaAngle;
  }

  static double exponentialFilter(double newValue, double previousValue,
      double filterFactor, bool isCircular) {
    double newValueP = newValue;
    if (isCircular) {
      if ((newValueP - previousValue).abs() > 180) {
        if (previousValue < 180 && newValue > 180) {
          newValueP -= 360;
        } else if (previousValue > 180 && newValueP < 180) {
          newValueP += 360;
        }
      }
    }
    final filteredValue =
        (newValueP * filterFactor) + (previousValue * (1.0 - filterFactor));
    return filteredValue;
  }

  static double bearingFromUserToLocation(
      Position userLocation, Position location,
      {bool approximate = false}) {
    double bearing = 0;
    if (approximate) {
      bearing = approximateBearingBetween(userLocation, location);
    } else {
      bearing = bearingBetween(userLocation, location);
    }
    return bearing;
  }

  static double bearingBetween(Position startLocation, Position endLocation) {
    double bearing = 0;
    final double lat1 = startLocation.latitude.toRadians;
    final double lon1 = startLocation.longitude.toRadians;

    final double lat2 = endLocation.latitude.toRadians;
    final double lon2 = endLocation.longitude.toRadians;

    final double dLon = lon2 - lon1;
    final double y = sin(dLon) * cos(lat2);
    final double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    final double radiansBearing = atan2(y, x);
    bearing = radiansBearing.toDegrees;
    if (bearing < 0) {
      bearing += 360;
    }

    return bearing;
  }

  static double approximateBearingBetween(
      Position startLocation, Position endLocation) {
    double bearing = 0;
    const double latLongFactor = 1.33975031663;

    final Position startCoordinate = startLocation;
    final Position endCoordinate = endLocation;

    final double latitudeDistance =
        startCoordinate.latitude - endCoordinate.latitude;
    final double longitudeDistance =
        startCoordinate.longitude - endCoordinate.longitude;

    bearing =
        (atan2(longitudeDistance, (latitudeDistance * latLongFactor.toDegrees)))
            .toDegrees;
    bearing += 180.0;

    return bearing;
  }

  static double calculatePitch({
    required Vector3 gravity,
    required NativeDeviceOrientation orientation,
  }) {
    double pitch = 0;
    if (orientation == NativeDeviceOrientation.portraitDown) {
      pitch = atan2(-gravity.y, gravity.z);
    } else if (orientation == NativeDeviceOrientation.landscapeLeft) {
      pitch = atan2(gravity.x, gravity.z);
    } else if (orientation == NativeDeviceOrientation.landscapeRight) {
      pitch = atan2(-gravity.x, gravity.z);
    } else {
      pitch = atan2(gravity.y, gravity.z);
    }
    pitch = pitch.toDegrees;
    pitch += 90;
    if (pitch > 180) {
      pitch -= 360;
    }
    return pitch;
  }
}
