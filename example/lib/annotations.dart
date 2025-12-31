import 'dart:math';

import 'package:ar_location_view/ar_annotation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

/// Types of annotations available in the example.
enum AnnotationType {
  pharmacy,
  hotel,
  library;

  /// Returns a random annotation type.
  static AnnotationType random() {
    final index = Random.secure().nextInt(values.length);
    return values[index];
  }
}

/// Custom annotation extending the base ArAnnotation.
///
/// Uses Dart 3 `base class` modifier for controlled inheritance.
final class Annotation extends ArAnnotation {
  final AnnotationType type;

  Annotation({
    required super.uid,
    required super.position,
    required this.type,
  });

  @override
  String toString() => 'Annotation(type: $type, ${super.toString()})';
}

/// Creates fake annotations for demonstration purposes.
///
/// [position] - Center position for generating annotations
/// [distance] - Maximum distance in meters
/// [numberMaxPoi] - Number of annotations to generate
List<Annotation> fakeAnnotation({
  required Position position,
  int distance = 1500,
  int numberMaxPoi = 100,
}) {
  const uuid = Uuid();

  return List.generate(
    numberMaxPoi,
    (_) => Annotation(
      uid: uuid.v4(),
      position: _getRandomLocation(
        centerLatitude: position.latitude,
        centerLongitude: position.longitude,
        deltaLat: distance / 100000,
        deltaLon: distance / 100000,
      ),
      type: AnnotationType.random(),
    ),
  );
}

/// Generates a random position within a delta range of the center.
Position _getRandomLocation({
  required double centerLatitude,
  required double centerLongitude,
  required double deltaLat,
  required double deltaLon,
}) {
  final random = Random.secure();

  final latDelta = -(deltaLat / 2) + random.nextDouble() * deltaLat;
  final lonDelta = -(deltaLon / 2) + random.nextDouble() * deltaLon;

  return Position(
    latitude: centerLatitude + latDelta,
    longitude: centerLongitude + lonDelta,
    timestamp: DateTime.now(),
    accuracy: 1,
    altitude: 1,
    heading: 1,
    speed: 1,
    speedAccuracy: 1,
    altitudeAccuracy: 0,
    headingAccuracy: 0,
  );
}
