import 'dart:math';
import 'dart:ui';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _TestAnnotation extends ArAnnotation {
  _TestAnnotation(String uid, double distance)
    : super(
        uid: uid,
        distanceFromUser: distance,
        position: Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime(2024),
          accuracy: 1,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        ),
      );
}

RadarPainter _painter({double? fieldOfView, List<ArAnnotation>? annotations}) {
  return fieldOfView == null
      ? RadarPainter(
          maxDistance: 100,
          arAnnotations: annotations ?? const [],
          heading: 30,
          markerColor: Colors.red,
          background: Colors.grey,
        )
      : RadarPainter(
          maxDistance: 100,
          arAnnotations: annotations ?? const [],
          heading: 30,
          markerColor: Colors.red,
          background: Colors.grey,
          fieldOfView: fieldOfView,
        );
}

void main() {
  test('draws a cone matching the field of view', () {
    expect(_painter(fieldOfView: 60).angle, closeTo(pi / 6, 1e-9));
  });

  test('keeps the former cone when the field of view is unknown', () {
    expect(_painter().angle, closeTo(pi / 7, 1e-9));
  });

  test('paints markers inside and beyond the range', () {
    final recorder = PictureRecorder();
    _painter(
      annotations: [
        _TestAnnotation('inside', 50),
        _TestAnnotation('beyond', 500),
      ],
    ).paint(Canvas(recorder), const Size(100, 100));

    expect(recorder.endRecording(), isNotNull);
  });
}
