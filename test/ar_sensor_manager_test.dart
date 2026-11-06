import 'dart:async';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

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

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeBackend {
  final accelerometer = StreamController<AccelerometerEvent>.broadcast();
  final compass = StreamController<CompassEvent>.broadcast();
  final position = StreamController<Position>.broadcast();

  PermissionStatus status = PermissionStatus.granted;
  PermissionStatus requestResult = PermissionStatus.granted;
  Completer<PermissionStatus>? pendingRequest;
  int statusChecks = 0;
  int requests = 0;
  LocationSettings? locationSettings;

  bool get sensorsRunning => compass.hasListener && position.hasListener;

  Future<void> close() =>
      Future.wait([accelerometer.close(), compass.close(), position.close()]);

  ArSensorBackend get backend => ArSensorBackend(
    accelerometer: () => accelerometer.stream,
    compass: () => compass.stream,
    position: ({locationSettings}) {
      this.locationSettings = locationSettings;
      return position.stream;
    },
    locationPermissionStatus: () async {
      statusChecks++;
      return status;
    },
    requestLocationPermission: () {
      requests++;
      return pendingRequest?.future ?? Future.value(requestResult);
    },
  );
}

Matcher _sensorError(ArSensorErrorType type) =>
    isA<ArSensorException>().having((e) => e.type, 'type', type);

void main() {
  late _FakeBackend fake;
  late ArSensorManager manager;

  ArSensorManager create({LocationSettings? locationSettings}) =>
      manager = ArSensorManager(
        smoothAttitude: false,
        smoothLocation: false,
        locationSettings: locationSettings,
        backend: fake.backend,
      );

  setUp(() => fake = _FakeBackend());

  tearDown(() {
    manager.dispose();
    return fake.close();
  });

  test('init is idempotent', () async {
    create()
      ..init()
      ..init();
    await _flush();

    expect(fake.statusChecks, 1);
    expect(fake.sensorsRunning, isTrue);
  });

  test('requests the permission when it is not granted yet', () async {
    fake.status = PermissionStatus.denied;
    create().init();
    await _flush();

    expect(fake.requests, 1);
    expect(fake.sensorsRunning, isTrue);
  });

  test('reports a denied permission', () async {
    fake
      ..status = PermissionStatus.denied
      ..requestResult = PermissionStatus.denied;
    create();
    final error = expectLater(
      manager.arSensor,
      emitsError(_sensorError(ArSensorErrorType.permissionDenied)),
    );
    manager.init();

    await error;
    expect(fake.sensorsRunning, isFalse);
  });

  test('reports a permanently denied permission without prompting', () async {
    fake.status = PermissionStatus.permanentlyDenied;
    create();
    final error = expectLater(
      manager.arSensor,
      emitsError(_sensorError(ArSensorErrorType.permissionPermanentlyDenied)),
    );
    manager.init();

    await error;
    expect(fake.requests, 0);
  });

  test('does not start the sensors when disposed during the prompt', () async {
    fake
      ..status = PermissionStatus.denied
      ..pendingRequest = Completer();
    create().init();
    await _flush();
    manager.dispose();
    fake.pendingRequest!.complete(PermissionStatus.granted);
    await _flush();

    expect(fake.sensorsRunning, isFalse);
  });

  test('reports disabled location services', () async {
    create().init();
    await _flush();
    final error = expectLater(
      manager.arSensor,
      emitsError(_sensorError(ArSensorErrorType.locationServiceDisabled)),
    );
    fake.position.addError(const LocationServiceDisabledException());

    await error;
  });

  test('emits the location', () async {
    create().init();
    await _flush();
    final sample = manager.arSensor.first;
    fake.position.add(_at(1));

    expect((await sample).location?.latitude, 1);
  });

  test('passes the location settings to the position stream', () async {
    const settings = LocationSettings(distanceFilter: 5);
    create(locationSettings: settings).init();
    await _flush();

    expect(fake.locationSettings, same(settings));
  });

  test('takes heading and pitch from the rotation matrix', () async {
    create().init();
    await _flush();
    expect(fake.accelerometer.hasListener, isTrue);

    final sample = manager.arSensor.first;
    fake.compass.add(
      CompassEvent.fromList([0, 0, 5, ...ArRotation.fromHeadingPitch(90, 10)]),
    );
    final arSensor = await sample;

    expect(arSensor.heading, closeTo(90, 1e-6));
    expect(arSensor.pitch, closeTo(10, 1e-6));
    expect(arSensor.compassAccuracy, 5);
    expect(arSensor.rotationMatrix, isNotNull);
    // The accelerometer pitch fallback is no longer needed.
    expect(fake.accelerometer.hasListener, isFalse);
  });

  test('falls back to the plain heading without a rotation matrix', () async {
    create().init();
    await _flush();
    final sample = manager.arSensor.first;
    fake.compass.add(CompassEvent.fromList([42, 42, -1]));
    final arSensor = await sample;

    expect(arSensor.heading, 42);
    expect(arSensor.compassAccuracy, -1);
    expect(arSensor.rotationMatrix, isNull);
  });

  group('orientation', () {
    // Device upright in landscape left: gravity along its x axis.
    AccelerometerEvent upright() =>
        AccelerometerEvent(9.81, 0, 0, DateTime(2024));

    test('is the one sent with the compass events', () async {
      create().init();
      await _flush();
      final sample = manager.arSensor.first;
      fake.compass.add(
        CompassEvent.fromList([
          0,
          0,
          5,
          ...ArRotation.fromHeadingPitch(0, 0),
          1,
        ]),
      );

      expect((await sample).orientation, DeviceOrientation.landscapeLeft);
    });

    test('is used by the accelerometer pitch fallback', () async {
      create().init();
      await _flush();
      fake.compass.add(CompassEvent.fromList([0, 0, 5, 1]));
      await _flush();
      final sample = manager.arSensor.first;
      fake.accelerometer.add(upright());
      final arSensor = await sample;

      expect(arSensor.orientation, DeviceOrientation.landscapeLeft);
      expect(arSensor.pitch, closeTo(0, 1e-6));
    });

    test('defaults to portrait up', () async {
      create().init();
      await _flush();
      final sample = manager.arSensor.first;
      // Upright in portrait: gravity along the device y axis.
      fake.accelerometer.add(AccelerometerEvent(0, 9.81, 0, DateTime(2024)));
      final arSensor = await sample;

      expect(arSensor.orientation, DeviceOrientation.portraitUp);
      expect(arSensor.pitch, closeTo(0, 1e-6));
    });
  });

  group('pause', () {
    test('stops the sensors until resume', () async {
      create().init();
      await _flush();

      manager.pause();
      expect(fake.sensorsRunning, isFalse);
      expect(fake.accelerometer.hasListener, isFalse);

      manager.resume();
      expect(fake.sensorsRunning, isTrue);
    });

    test(
      'defers the start when the permission resolves while paused',
      () async {
        fake
          ..status = PermissionStatus.denied
          ..pendingRequest = Completer();
        create().init();
        await _flush();
        manager.pause();
        fake.pendingRequest!.complete(PermissionStatus.granted);
        await _flush();
        expect(fake.sensorsRunning, isFalse);

        manager.resume();
        expect(fake.sensorsRunning, isTrue);
      },
    );

    test('rechecks a denied permission on resume without prompting', () async {
      fake
        ..status = PermissionStatus.denied
        ..requestResult = PermissionStatus.denied;
      create().init();
      await _flush();
      expect(fake.sensorsRunning, isFalse);

      // Granted from the system settings while in background.
      fake.status = PermissionStatus.granted;
      manager
        ..pause()
        ..resume();
      await _flush();

      expect(fake.statusChecks, 2);
      expect(fake.requests, 1);
      expect(fake.sensorsRunning, isTrue);
    });
  });
}
