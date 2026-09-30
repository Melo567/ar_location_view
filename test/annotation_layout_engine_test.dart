import 'dart:math';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class _TestAnnotation extends ArAnnotation {
  _TestAnnotation(String uid, Position position)
      : super(uid: uid, position: position);
}

Position _dueNorthOf(Position origin, double latitudeOffset) => Position(
      latitude: origin.latitude + latitudeOffset,
      longitude: origin.longitude,
      timestamp: DateTime(2024),
      accuracy: 1,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );

void main() {
  const engine = AnnotationLayoutEngine();
  const config = AnnotationLayoutConfig(
    annotationWidth: 200,
    annotationHeight: 75,
    maxVisibleDistance: 1500,
    paddingOverlap: 5,
  );
  final device = _dueNorthOf(
    Position(
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
    0,
  );

  ArSensor sensorFacingNorth() => ArSensor(
        heading: 0,
        pitch: 0,
        orientation: NativeDeviceOrientation.portraitUp,
        compassAccuracy: 1,
        location: device,
      );

  test('stacks annotations that fully overlap onto distinct, ordered rows', () {
    // All three POIs sit due north of the device at the same bearing, so
    // once projected they land at the exact same x - the worst case for
    // horizontal overlap - only distance differs.
    final annotations = [
      _TestAnnotation('near', _dueNorthOf(device, 0.001)),
      _TestAnnotation('mid', _dueNorthOf(device, 0.002)),
      _TestAnnotation('far', _dueNorthOf(device, 0.003)),
    ];

    final result = engine.layout(
      annotations: annotations,
      arSensor: sensorFacingNorth(),
      deviceLocation: device,
      width: 400,
      height: 800,
      config: config,
    );

    expect(
        result.annotations.map((a) => a.uid).toList(), ['near', 'mid', 'far'],
        reason: 'result must stay sorted by distance ascending for '
            "ArView's z-ordering");

    final rowsByUid = {
      for (final a in result.annotations) a.uid: a.arPositionOffset.dy,
    };
    expect(rowsByUid['near'], 0, reason: 'closest POI keeps its natural row');
    expect(rowsByUid.values.toSet().length, 3,
        reason: 'three mutually-overlapping POIs need three distinct rows');
    expect(rowsByUid['mid']! < rowsByUid['near']!, isTrue);
    expect(rowsByUid['far']! < rowsByUid['mid']!, isTrue);
  });

  test('does not shift annotations that do not overlap horizontally', () {
    final annotations = [
      _TestAnnotation('a', _dueNorthOf(device, 0.001)),
    ];

    final result = engine.layout(
      annotations: annotations,
      arSensor: sensorFacingNorth(),
      deviceLocation: device,
      width: 400,
      height: 800,
      config: config,
    );

    expect(result.annotations.single.arPositionOffset, Offset.zero);
  });

  test('centers a POI straight ahead horizontally on screen', () {
    final result = engine.layout(
      annotations: [_TestAnnotation('ahead', _dueNorthOf(device, 0.001))],
      arSensor: sensorFacingNorth(),
      deviceLocation: device,
      width: 400,
      height: 800,
      config: config,
    );

    final left = result.annotations.single.arPosition.dx;
    expect(left + config.annotationWidth / 2, closeTo(200, 0.001));
  });

  test('only keeps POIs inside the displayed horizontal field of view', () {
    ArSensor sensorFacing(double heading) => ArSensor(
          heading: heading,
          pitch: 0,
          orientation: NativeDeviceOrientation.portraitUp,
          compassAccuracy: 1,
          location: device,
        );
    List<ArAnnotation> layoutFacing(double heading) => engine.layout(
          annotations: [_TestAnnotation('north', _dueNorthOf(device, 0.001))],
          arSensor: sensorFacing(heading),
          deviceLocation: device,
          width: 400,
          height: 800,
          config: config,
        ).annotations;

    // Portrait 400x800 with a 58° camera FOV on the long side gives a focal
    // length of 400 / tan(29°) ≈ 721.6 px. A 200 px label stays on screen
    // while its center is within 300 px of the middle, i.e. while
    // tan(delta) < 300 / 721.6: up to ≈ 22.6° off-axis, on both sides.
    expect(layoutFacing(20), hasLength(1));
    expect(layoutFacing(-20), hasLength(1));
    expect(layoutFacing(30), isEmpty);
    expect(layoutFacing(-30), isEmpty);
  });

  group('row stability', () {
    const metersPerDegree = 111319.49;
    final focal = 400 / tan(29 * pi / 180);

    /// POI 200 m away whose label is centered at screen x [centerX].
    _TestAnnotation farPoiAt(double centerX) {
      final azimuth = atan((centerX - 200) / focal);
      return _TestAnnotation(
        'far',
        Position(
          latitude: 200 * cos(azimuth) / metersPerDegree,
          longitude: 200 * sin(azimuth) / metersPerDegree,
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

    AnnotationLayoutResult layoutWithFarAt(double centerX,
            {Map<String, int> previousRows = const {}}) =>
        engine.layout(
          // The near POI's label spans [100, 300].
          annotations: [
            _TestAnnotation('near', _dueNorthOf(device, 0.0009)),
            farPoiAt(centerX),
          ],
          arSensor: sensorFacingNorth(),
          deviceLocation: device,
          width: 400,
          height: 800,
          config: config,
          previousRows: previousRows,
        );

    test('returns the row of each annotation', () {
      final result = layoutWithFarAt(350);
      expect(result.rows, {'near': 0, 'far': 1});
    });

    test('keeps a label on its row until there is enough clearance below', () {
      final stacked = layoutWithFarAt(350).rows;

      // 10 px of clearance: fits on row 0, but less than the hysteresis.
      expect(layoutWithFarAt(410).rows['far'], 0,
          reason: 'without history the lowest free row is used');
      expect(layoutWithFarAt(410, previousRows: stacked).rows['far'], 1);

      // 50 px of clearance: moves back down.
      expect(layoutWithFarAt(450, previousRows: stacked).rows['far'], 0);
    });
  });

  test('can hide POIs closer than the location accuracy', () {
    final imprecise = Position(
      latitude: 0,
      longitude: 0,
      timestamp: DateTime(2024),
      accuracy: 50,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    // ~33 m north.
    final annotations = [_TestAnnotation('close', _dueNorthOf(device, 0.0003))];
    List<ArAnnotation> layout({required bool hide}) => engine
        .layout(
          annotations: annotations,
          arSensor: sensorFacingNorth(),
          deviceLocation: imprecise,
          width: 400,
          height: 800,
          config: AnnotationLayoutConfig(
            annotationWidth: 200,
            annotationHeight: 75,
            maxVisibleDistance: 1500,
            paddingOverlap: 5,
            hideWithinLocationAccuracy: hide,
          ),
        )
        .annotations;

    expect(layout(hide: false), hasLength(1));
    expect(layout(hide: true), isEmpty);
  });

  group('grouping', () {
    List<ArAnnotation> threeOverlapping() => [
          _TestAnnotation('near', _dueNorthOf(device, 0.001)),
          _TestAnnotation('mid', _dueNorthOf(device, 0.002)),
          _TestAnnotation('far', _dueNorthOf(device, 0.003)),
        ];

    AnnotationLayoutResult layout(List<ArAnnotation> annotations,
            {double height = 800, int? maxRows}) =>
        engine.layout(
          annotations: annotations,
          arSensor: sensorFacingNorth(),
          deviceLocation: device,
          width: 400,
          height: height,
          config: AnnotationLayoutConfig(
            annotationWidth: 200,
            annotationHeight: 75,
            maxVisibleDistance: 1500,
            paddingOverlap: 5,
            maxRows: maxRows,
          ),
        );

    test('groups the farthest annotations beyond maxRows', () {
      final annotations = threeOverlapping();
      final result = layout(annotations, maxRows: 2);

      expect(result.annotations.map((a) => a.uid), ['near', 'mid']);
      expect(result.groups.keys, ['near']);
      expect(result.groups['near']!.map((a) => a.uid), ['far']);
      expect(annotations.last.isVisible, isFalse);
      expect(result.rows.containsKey('far'), isFalse);
    });

    test('never stacks a label above the top of the screen', () {
      // 200 px high: the label (75 px) centered at y = 100 has its top at
      // 62.5 px, less than one 80 px row step: no room to stack at all.
      final result = layout(threeOverlapping(), height: 200);

      expect(result.annotations.map((a) => a.uid), ['near']);
      expect(result.groups['near']!.map((a) => a.uid), ['mid', 'far']);
    });

    test('does not group anything when every label fits', () {
      final result = layout(threeOverlapping());
      expect(result.annotations, hasLength(3));
      expect(result.groups, isEmpty);
    });
  });

  group('scale', () {
    const metersPerDegree = 111319.49;
    final focal = 400 / tan(29 * pi / 180);

    _TestAnnotation poi(String uid, double meters, double centerX) {
      final azimuth = atan((centerX - 200) / focal);
      return _TestAnnotation(
        uid,
        Position(
          latitude: meters * cos(azimuth) / metersPerDegree,
          longitude: meters * sin(azimuth) / metersPerDegree,
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

    AnnotationLayoutResult layout(List<ArAnnotation> annotations,
            {required bool scale}) =>
        engine.layout(
          annotations: annotations,
          arSensor: sensorFacingNorth(),
          deviceLocation: device,
          width: 400,
          height: 800,
          config: AnnotationLayoutConfig(
            annotationWidth: 200,
            annotationHeight: 75,
            maxVisibleDistance: 1000,
            paddingOverlap: 5,
            scaleWithDistance: scale,
            minScale: 0.5,
          ),
        );

    test('shrinks labels linearly down to minScale', () {
      final result = layout([
        poi('a', 1, 200),
        poi('b', 500, 200),
        poi('c', 999, 200),
      ], scale: true);
      final scales = {for (final a in result.annotations) a.uid: a.arScale};
      expect(scales['a'], closeTo(1, 0.001));
      expect(scales['b'], closeTo(0.75, 0.001));
      expect(scales['c'], closeTo(0.5, 0.001));
    });

    test('uses the displayed (scaled) width to detect overlaps', () {
      // Centers 150 px apart: 200 px labels overlap, labels scaled to ~0.5
      // (~100 px + spacing) do not.
      List<ArAnnotation> twoFar() =>
          [poi('left', 990, 125), poi('right', 995, 275)];

      expect(layout(twoFar(), scale: false).rows, {'left': 0, 'right': 1});
      expect(layout(twoFar(), scale: true).rows, {'left': 0, 'right': 0});
    });
  });

  group('AnnotationGeoCache', () {
    test('reuses bearing and distance until the user or the POI moves', () {
      final cache = AnnotationGeoCache()..prepare(device, 1);
      final annotation = _TestAnnotation('a', _dueNorthOf(device, 0.001))
        ..azimuth = 12
        ..distanceFromUser = 34;
      cache.store(annotation);

      final copy = _TestAnnotation('a', annotation.position);
      expect(cache.restore(copy), isTrue);
      expect(copy.azimuth, 12);
      expect(copy.distanceFromUser, 34);

      // The POI moved.
      expect(cache.restore(_TestAnnotation('a', _dueNorthOf(device, 0.002))),
          isFalse);

      // The user moved.
      cache.prepare(_dueNorthOf(device, 0.0001), 1);
      expect(cache.restore(copy), isFalse);
    });

    test('gives the same layout as without cache', () {
      final cache = AnnotationGeoCache();
      List<Offset> positions({AnnotationGeoCache? geoCache}) => engine
          .layout(
            annotations: [
              _TestAnnotation('a', _dueNorthOf(device, 0.001)),
              _TestAnnotation('b', _dueNorthOf(device, 0.002)),
            ],
            arSensor: sensorFacingNorth(),
            deviceLocation: device,
            width: 400,
            height: 800,
            config: config,
            geoCache: geoCache,
          )
          .annotations
          .map((a) => a.arPosition + a.arPositionOffset)
          .toList();

      final expected = positions();
      expect(positions(geoCache: cache), expected);
      expect(positions(geoCache: cache), expected, reason: 'from the cache');
    });
  });
}
