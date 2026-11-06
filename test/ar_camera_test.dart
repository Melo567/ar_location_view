import 'dart:async';

import 'package:ar_location_view/ar_location_view.dart';
import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

class _FakePermissions extends PermissionHandlerPlatform {
  PermissionStatus status = PermissionStatus.denied;

  /// Created inside the test body when set: a future completed outside
  /// `testWidgets`' fake async zone (e.g. in `setUp`) is never delivered.
  Completer<PermissionStatus>? pendingRequest;
  int checks = 0;

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async {
    checks++;
    return status;
  }

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async {
    final result =
        await (pendingRequest?.future ?? Future.value(PermissionStatus.denied));
    return {for (final permission in permissions) permission: result};
  }

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      ServiceStatus.enabled;

  @override
  Future<bool> openAppSettings() async => false;

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async => false;
}

void main() {
  late _FakePermissions permissions;
  late List<String> errors;

  setUp(() {
    permissions = _FakePermissions();
    PermissionHandlerPlatform.instance = permissions;
    errors = [];
  });

  Widget app({ArCameraErrorBuilder? errorBuilder}) => MaterialApp(
    home: ArCamera(
      onCameraError: errors.add,
      onCameraSuccess: () {},
      errorBuilder: errorBuilder,
    ),
  );

  testWidgets('shows a loading indicator while the permission is requested', (
    tester,
  ) async {
    permissions.pendingRequest = Completer();
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('permission'), findsNothing);
  });

  testWidgets('shows the default message when the permission is denied', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Camera permission denied'), findsOneWidget);
    expect(errors, hasLength(1));
  });

  testWidgets('uses the error builder', (tester) async {
    await tester.pumpWidget(
      app(errorBuilder: (_, error) => Text('custom ${error.name}')),
    );
    await tester.pumpAndSettle();

    expect(find.text('custom permissionDenied'), findsOneWidget);
  });

  testWidgets('starts the camera once granted from the settings', (
    tester,
  ) async {
    // A device without any camera: the start is attempted and fails.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/camera'),
      (call) async => call.method == 'availableCameras' ? <Object>[] : null,
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final checks = permissions.checks;

    permissions.status = PermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(permissions.checks, checks + 1);
    expect(find.text('Camera unavailable'), findsOneWidget);
  });

  group('preview', () {
    double? aspectRatio;

    Future<Rect> pumpPreview(
      WidgetTester tester, {
      required Size view,
      required Size previewSize,
      required DeviceOrientation deviceOrientation,
    }) async {
      tester.view.physicalSize = view;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      permissions.status = PermissionStatus.granted;
      CameraPlatform.instance = _WorkingCamera(previewSize, deviceOrientation);
      await tester.pumpWidget(
        MaterialApp(
          home: ArCamera(
            onCameraError: errors.add,
            onCameraSuccess: () {},
            onPreviewAspectRatio: (ratio) => aspectRatio = ratio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(CameraPreview));
    }

    setUp(() => aspectRatio = null);

    testWidgets('follows the UI when it is locked in portrait', (tester) async {
      // Held in landscape, while the UI stays in portrait.
      final rect = await pumpPreview(
        tester,
        view: const Size(400, 800),
        previewSize: const Size(1280, 720),
        deviceOrientation: DeviceOrientation.landscapeLeft,
      );

      final size = tester.getSize(find.byType(CameraPreview));
      expect(size.height / size.width, closeTo(1280 / 720, 1e-9));
      // Covers the whole view, centered.
      expect(rect.width, greaterThanOrEqualTo(400 - 1e-6));
      expect(rect.height, closeTo(800, 1e-6));
      expect(rect.center, const Offset(200, 400));
      expect(aspectRatio, closeTo(1280 / 720, 1e-9));
    });

    testWidgets('covers a landscape UI', (tester) async {
      final rect = await pumpPreview(
        tester,
        view: const Size(800, 300),
        previewSize: const Size(1280, 720),
        deviceOrientation: DeviceOrientation.landscapeLeft,
      );

      final size = tester.getSize(find.byType(CameraPreview));
      expect(size.width / size.height, closeTo(1280 / 720, 1e-9));
      expect(rect.width, closeTo(800, 1e-6));
      expect(rect.height, greaterThanOrEqualTo(300 - 1e-6));
    });

    testWidgets('reports a long/short ratio whatever the preview size order', (
      tester,
    ) async {
      await pumpPreview(
        tester,
        view: const Size(400, 800),
        previewSize: const Size(720, 1280),
        deviceOrientation: DeviceOrientation.portraitUp,
      );

      expect(aspectRatio, closeTo(1280 / 720, 1e-9));
    });
  });
}

/// A back camera that initializes with [previewSize] and reports the
/// physical [deviceOrientation].
class _WorkingCamera extends CameraPlatform {
  _WorkingCamera(this.previewSize, this.deviceOrientation);

  final Size previewSize;
  final DeviceOrientation deviceOrientation;

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'back',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Future<int> createCameraWithSettings(
    CameraDescription cameraDescription,
    MediaSettings? mediaSettings,
  ) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          previewSize.width,
          previewSize.height,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) =>
      // Never emits: the controller awaits its first event, which an empty
      // stream would fail.
      Stream.fromFuture(Completer<CameraErrorEvent>().future);

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      Stream.value(DeviceOrientationChangedEvent(deviceOrientation));

  @override
  Widget buildPreview(int cameraId) => const ColoredBox(color: Colors.black);

  @override
  Future<void> dispose(int cameraId) async {}
}
