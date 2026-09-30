import 'dart:math';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

Position _fix(double latitude, double accuracy, int second) => Position(
      latitude: latitude,
      longitude: 0,
      timestamp: DateTime(2024).add(Duration(seconds: second)),
      accuracy: accuracy,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

void main() {
  group('AttitudeFilter', () {
    test('returns the first sample unchanged', () {
      final m = ArRotation.fromHeadingPitch(30, 5);
      expect(AttitudeFilter().add(m, 0), m);
    });

    test('damps small jitter while the device is still', () {
      final filter = AttitudeFilter()
        ..add(ArRotation.fromHeadingPitch(0, 0), 0);
      // One 60 Hz sample with 1° of compass noise.
      final output = filter.add(ArRotation.fromHeadingPitch(1, 0), 1 / 60);
      final heading = ArRotation.heading(output);
      expect(heading, greaterThan(0));
      expect(heading, lessThan(0.2));
    });

    test('follows fast rotations without lag', () {
      final filter = AttitudeFilter()
        ..add(ArRotation.fromHeadingPitch(0, 0), 0);
      final output = filter.add(ArRotation.fromHeadingPitch(20, 0), 1 / 60);
      expect(ArRotation.heading(output), closeTo(20, 1e-9));
    });

    test('keeps a proper rotation matrix', () {
      final filter = AttitudeFilter()
        ..add(ArRotation.fromHeadingPitch(0, 0), 0);
      final m = filter.add(ArRotation.fromHeadingPitch(4, -3), 1 / 60);
      double dot(int a, int b) =>
          m[a * 3] * m[b * 3] +
          m[a * 3 + 1] * m[b * 3 + 1] +
          m[a * 3 + 2] * m[b * 3 + 2];
      for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
          expect(dot(i, j), closeTo(i == j ? 1 : 0, 1e-9));
        }
      }
    });
  });

  group('HeadingFilter', () {
    test('smooths across north instead of averaging to 180°', () {
      final filter = HeadingFilter()..add(359, 0);
      final heading = filter.add(1, 1 / 60);
      expect(min(heading, 360 - heading), lessThan(1));
    });
  });

  group('LocationFilter', () {
    test('returns the first fix unchanged', () {
      final fix = _fix(0, 10, 0);
      expect(LocationFilter().add(fix), fix);
    });

    test('an imprecise fix barely moves a precise estimate', () {
      final filter = LocationFilter()..add(_fix(0, 5, 0));
      final estimate = filter.add(_fix(0.001, 100, 1));
      expect(estimate.latitude, lessThan(0.001 * 0.05));
    });

    test('a precise fix pulls an imprecise estimate', () {
      final filter = LocationFilter()..add(_fix(0, 100, 0));
      final estimate = filter.add(_fix(0.001, 5, 1));
      expect(estimate.latitude, greaterThan(0.001 * 0.95));
      expect(estimate.accuracy, lessThan(5));
    });

    test('follows the user after a long gap', () {
      final filter = LocationFilter()..add(_fix(0, 5, 0));
      // After 5 min at up to 3 m/s the old estimate is worth little:
      // variance 5² + 300·3² = 2725 m², gain 2725 / (2725 + 10²) ≈ 0.965.
      final estimate = filter.add(_fix(0.001, 10, 300));
      expect(estimate.latitude, closeTo(0.001 * 2725 / 2825, 1e-12));
    });
  });
}
