import 'dart:async';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class _TestAnnotation extends ArAnnotation {
  _TestAnnotation(String uid, Position position)
    : super(uid: uid, position: position);
}

Position _at(double latitude) => Position(
  latitude: latitude,
  longitude: 0,
  timestamp: DateTime(2024),
  accuracy: 1,
  altitude: 0,
  heading: 0,
  speed: 0,
  speedAccuracy: 0,
  altitudeAccuracy: 0,
  headingAccuracy: 0,
);

class _FakeSensorSource implements ArSensorSource {
  final StreamController<ArSensor> controller = StreamController.broadcast();
  int initCount = 0;
  bool disposed = false;

  @override
  void init() => initCount++;

  @override
  Stream<ArSensor> get arSensor => controller.stream;

  @override
  void dispose() {
    disposed = true;
    controller.close();
  }
}

Widget _app(ArSensorSource source, {ArSensorErrorBuilder? errorBuilder}) {
  return MaterialApp(
    home: ArView(
      annotations: const [],
      annotationViewBuilder: (_, _) => const SizedBox(),
      onLocationChange: (_) {},
      minDistanceReload: 50,
      showRadar: false,
      sensorSource: source,
      sensorErrorBuilder: errorBuilder,
    ),
  );
}

void main() {
  testWidgets('does not dispose a sensor source it does not own', (
    tester,
  ) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(_app(source));
    expect(source.initCount, 1);

    await tester.pumpWidget(const SizedBox());
    expect(source.disposed, isFalse);
    source.dispose();
  });

  testWidgets('shares one broadcast source between several views', (
    tester,
  ) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(
      Column(
        children: [
          Expanded(child: _app(source)),
          Expanded(child: _app(source)),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(source.initCount, 2);
    source.dispose();
  });

  testWidgets('shows the error builder when the source reports an error', (
    tester,
  ) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(
      _app(
        source,
        errorBuilder: (_, error) => Text('error: ${error.type.name}'),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    source.controller.addError(
      const ArSensorException(ArSensorErrorType.permissionDenied),
    );
    await tester.pump();

    expect(find.text('error: permissionDenied'), findsOneWidget);
    source.dispose();
  });

  testWidgets('wraps unknown errors into an ArSensorException', (tester) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(
      _app(
        source,
        errorBuilder: (_, error) => Text('error: ${error.type.name}'),
      ),
    );

    source.controller.addError(StateError('boom'));
    await tester.pump();

    expect(find.text('error: unknown'), findsOneWidget);
    source.dispose();
  });

  testWidgets('shows a +N badge on labels with grouped annotations', (
    tester,
  ) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(
      MaterialApp(
        home: ArView(
          // Same bearing, so all three labels overlap.
          annotations: [
            _TestAnnotation('near', _at(0.001)),
            _TestAnnotation('mid', _at(0.002)),
            _TestAnnotation('far', _at(0.003)),
          ],
          annotationViewBuilder: (_, annotation) => Text(annotation.uid),
          onLocationChange: (_) {},
          minDistanceReload: 50,
          showRadar: false,
          showDebugInfoSensor: false,
          scaleWithDistance: false,
          maxRows: 1,
          sensorSource: source,
        ),
      ),
    );

    source.controller.add(
      ArSensor(
        heading: 0,
        pitch: 0,
        orientation: NativeDeviceOrientation.portraitUp,
        compassAccuracy: 1,
        location: _at(0),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('near'), findsOneWidget);
    expect(find.text('mid'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
    source.dispose();
  });

  testWidgets('projects onto its own size, not the screen', (tester) async {
    final source = _FakeSensorSource();
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 300,
            child: ArView(
              annotations: [_TestAnnotation('poi', _at(0.001))],
              annotationViewBuilder: (_, annotation) =>
                  Center(child: Text(annotation.uid)),
              onLocationChange: (_) {},
              minDistanceReload: 50,
              showRadar: false,
              showDebugInfoSensor: false,
              scaleWithDistance: false,
              sensorSource: source,
            ),
          ),
        ),
      ),
    );

    source.controller.add(
      ArSensor(
        heading: 0,
        pitch: 0,
        orientation: NativeDeviceOrientation.portraitUp,
        compassAccuracy: 1,
        location: _at(0),
      ),
    );
    await tester.pumpAndSettle();

    // A POI straight ahead is centered in the 200x300 view (the test screen
    // is 800x600).
    expect(tester.getCenter(find.text('poi')), const Offset(100, 150));
    source.dispose();
  });

  group('annotation view cache', () {
    late _FakeSensorSource source;
    late int builds;

    Future<void> pumpView(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ArView(
            annotations: [_TestAnnotation('poi', _at(0.001))],
            annotationViewBuilder: (_, annotation) {
              builds++;
              return Text(
                '${annotation.uid} ${annotation.distanceFromUser.round()}',
              );
            },
            onLocationChange: (_) {},
            minDistanceReload: 50,
            showRadar: false,
            showDebugInfoSensor: false,
            sensorSource: source,
          ),
        ),
      );
    }

    ArSensor sample({double heading = 0, double latitude = 0}) => ArSensor(
      heading: heading,
      pitch: 0,
      orientation: NativeDeviceOrientation.portraitUp,
      compassAccuracy: 1,
      location: _at(latitude),
    );

    setUp(() {
      source = _FakeSensorSource();
      builds = 0;
    });

    tearDown(() => source.dispose());

    testWidgets('does not rebuild labels when only the attitude changes', (
      tester,
    ) async {
      await pumpView(tester);
      for (var heading = 0.0; heading < 5; heading++) {
        source.controller.add(sample(heading: heading));
        await tester.pump();
      }

      expect(find.text('poi 111'), findsOneWidget);
      expect(builds, 1);
    });

    testWidgets('rebuilds a label when its distance changes', (tester) async {
      await pumpView(tester);
      source.controller.add(sample());
      await tester.pump();
      source.controller.add(sample(latitude: -0.001));
      await tester.pump();

      expect(find.text('poi 223'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('lays out only the last sample received before a frame', (
      tester,
    ) async {
      await pumpView(tester);
      source.controller.add(sample(latitude: -0.002));
      source.controller.add(sample(latitude: -0.001));
      await tester.pump();

      expect(find.text('poi 223'), findsOneWidget);
      expect(builds, 1);
    });
  });

  testWidgets('does not pause a sensor manager it does not own', (
    tester,
  ) async {
    final accelerometer = StreamController<AccelerometerEvent>.broadcast();
    final manager = ArSensorManager(
      backend: ArSensorBackend(
        accelerometer: () => accelerometer.stream,
        compass: () => null,
        position: ({locationSettings}) => const Stream.empty(),
        orientation: () => const Stream.empty(),
        locationPermissionStatus: () async => PermissionStatus.granted,
        requestLocationPermission: () async => PermissionStatus.granted,
      ),
    );
    await tester.pumpWidget(_app(manager));
    await tester.pump();
    expect(accelerometer.hasListener, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(accelerometer.hasListener, isTrue);

    manager.dispose();
    await accelerometer.close();
  });
}
