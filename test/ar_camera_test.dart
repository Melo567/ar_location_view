import 'dart:async';

import 'package:ar_location_view/ar_location_view.dart';
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
}
