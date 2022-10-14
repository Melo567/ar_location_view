import 'package:geolocator/geolocator.dart';

Position positionBuilder({
  required double latitude,
  required double longitude,
  DateTime? timestamp,
  double? accuracy,
  double? altitude,
  double? heading,
  double? speed,
  double? speedAccuracy,
}) =>
    Position(
      longitude: longitude,
      latitude: latitude,
      timestamp: timestamp,
      accuracy: accuracy ?? 0.0,
      altitude: altitude ?? 0.0,
      heading: heading ?? 0.0,
      speed: speed ?? 0.0,
      speedAccuracy: speedAccuracy ?? 0.0,
    );