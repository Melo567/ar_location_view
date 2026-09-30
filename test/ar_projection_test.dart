import 'dart:math';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class _TestAnnotation extends ArAnnotation {
  _TestAnnotation(String uid, Position position)
      : super(uid: uid, position: position);
}

/// ~111 km per degree of latitude; longitude at the equator is the same.
const _metersPerDegree = 111319.49;

Position _position({
  double northMeters = 0,
  double eastMeters = 0,
  double altitude = 0,
}) =>
    Position(
      latitude: northMeters / _metersPerDegree,
      longitude: eastMeters / _metersPerDegree,
      timestamp: DateTime(2024),
      accuracy: 1,
      altitude: altitude,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

double _rad(double degrees) => degrees * pi / 180;

/// Rotates the screen frame of [m] by [roll] degrees around the camera axis
/// (positive = device rotated clockwise as seen by the user).
List<double> _withRoll(List<double> m, double roll) {
  final c = cos(_rad(roll));
  final s = sin(_rad(roll));
  // New screen axes expressed in the old ones: x' = c·x - s·y, y' = s·x + c·y.
  return [
    c * m[0] - s * m[3],
    c * m[1] - s * m[4],
    c * m[2] - s * m[5],
    s * m[0] + c * m[3],
    s * m[1] + c * m[4],
    s * m[2] + c * m[5],
    m[6],
    m[7],
    m[8],
  ];
}

void main() {
  const engine = AnnotationLayoutEngine();
  const width = 400.0;
  const height = 800.0;
  const config = AnnotationLayoutConfig(
    annotationWidth: 200,
    annotationHeight: 80,
    maxVisibleDistance: 5000,
    paddingOverlap: 5,
  );
  final device = _position();
  final focal = 400 / tan(_rad(29)); // 58° over the 800 px long side.

  ArSensor sensor({double heading = 0, double pitch = 0, List<double>? m}) =>
      ArSensor(
        heading: heading,
        pitch: pitch,
        orientation: NativeDeviceOrientation.portraitUp,
        compassAccuracy: 1,
        location: device,
        rotationMatrix: m,
      );

  /// Screen point the POI's label is centered on, or null if not visible.
  Offset? project(Position poi, ArSensor arSensor,
      {AnnotationLayoutConfig layoutConfig = config}) {
    final result = engine.layout(
      annotations: [_TestAnnotation('poi', poi)],
      arSensor: arSensor,
      deviceLocation: device,
      width: width,
      height: height,
      config: layoutConfig,
    );
    if (result.annotations.isEmpty) return null;
    final a = result.annotations.single;
    return a.arPosition +
        Offset(layoutConfig.annotationWidth / 2,
            layoutConfig.annotationHeight / 2);
  }

  group('ArRotation', () {
    test('round-trips heading and pitch', () {
      for (final heading in [0.0, 45.0, 181.0, 359.0]) {
        for (final pitch in [-60.0, 0.0, 30.0]) {
          final m = ArRotation.fromHeadingPitch(heading, pitch);
          expect(ArRotation.heading(m), closeTo(heading, 1e-9));
          expect(ArRotation.pitch(m), closeTo(pitch, 1e-9));
        }
      }
    });

    test('an upright device facing north has the expected attitude', () {
      // Screen x = East, y = Up, z (towards the viewer) = South.
      final m = ArRotation.fromHeadingPitch(0, 0);
      const expected = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0];
      for (var i = 0; i < 9; i++) {
        expect(m[i], closeTo(expected[i], 1e-12), reason: 'element $i');
      }
    });
  });

  group('ArProjection', () {
    test('uses the long side FOV when the screen is more elongated', () {
      final projection = ArProjection(
          width: 400,
          height: 800,
          cameraFieldOfView: 58,
          previewAspectRatio: 4 / 3);
      expect(projection.focalLength, closeTo(focal, 1e-9));
      expect(projection.verticalFieldOfView, closeTo(58, 1e-9));
    });

    test('crops the long side when the screen is squarer than the preview', () {
      // 4:3 tablet screen, 16:9 preview: the short side must be covered.
      final projection = ArProjection(
          width: 768,
          height: 1024,
          cameraFieldOfView: 60,
          previewAspectRatio: 16 / 9);
      final tanShort = tan(_rad(30)) / (16 / 9);
      expect(projection.focalLength, closeTo(384 / tanShort, 1e-9));
      expect(projection.verticalFieldOfView, lessThan(60));
    });
  });

  group('layout', () {
    test('centers a POI straight ahead on screen', () {
      final point = project(_position(northMeters: 100), sensor())!;
      expect(point.dx, closeTo(width / 2, 1e-6));
      expect(point.dy, closeTo(height / 2, 1e-6));
    });

    test('uses a pinhole (tan) projection horizontally', () {
      // 20° to the right of the heading.
      final poi = _position(
          northMeters: 100 * cos(_rad(20)), eastMeters: 100 * sin(_rad(20)));
      final point = project(poi, sensor())!;
      expect(point.dx, closeTo(width / 2 + focal * tan(_rad(20)), 0.5));
    });

    test('hides POIs behind the camera', () {
      expect(
          project(_position(northMeters: 100), sensor(heading: 180)), isNull);
    });

    test('moves POIs up when the camera points down', () {
      final point = project(_position(northMeters: 100), sensor(pitch: -10))!;
      expect(point.dy, closeTo(height / 2 - focal * tan(_rad(10)), 1e-6));
    });

    test('follows the device roll', () {
      final poi = _position(
          northMeters: 100 * cos(_rad(10)), eastMeters: 100 * sin(_rad(10)));
      final upright = ArRotation.fromHeadingPitch(0, 0);
      final flat = project(poi, sensor(m: upright))!;
      final rolled = project(poi, sensor(m: _withRoll(upright, 90)))!;

      // Without roll the POI is to the right, on the horizon line.
      expect(flat.dx, greaterThan(width / 2));
      expect(flat.dy, closeTo(height / 2, 1e-6));
      // Rotated by 90°, the horizon is vertical on screen: the same POI is
      // now straight above/below the center, at the same distance from it.
      expect(rolled.dx, closeTo(width / 2, 1e-6));
      expect(
          (rolled.dy - height / 2).abs(), closeTo(flat.dx - width / 2, 1e-6));
    });

    test('ignores altitude unless useAltitude is enabled', () {
      final hill = _position(northMeters: 100, altitude: 10);
      expect(project(hill, sensor())!.dy, closeTo(height / 2, 1e-6));

      const withAltitude = AnnotationLayoutConfig(
        annotationWidth: 200,
        annotationHeight: 80,
        maxVisibleDistance: 5000,
        paddingOverlap: 5,
        useAltitude: true,
      );
      // 10 m higher at ~100 m: ~5.7° above the horizon.
      final point = project(hill, sensor(), layoutConfig: withAltitude)!;
      final distance =
          Geolocator.distanceBetween(0, 0, hill.latitude, hill.longitude);
      final elevation = atan2(10, distance);
      expect(point.dy, closeTo(height / 2 - focal * tan(elevation), 1e-6));
    });

    test('centers the label vertically on the projected point', () {
      final result = engine.layout(
        annotations: [_TestAnnotation('poi', _position(northMeters: 100))],
        arSensor: sensor(),
        deviceLocation: device,
        width: width,
        height: height,
        config: config,
      );
      expect(result.annotations.single.arPosition,
          const Offset(width / 2 - 100, height / 2 - 40));
    });
  });
}
