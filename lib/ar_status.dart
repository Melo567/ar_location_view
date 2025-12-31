import 'package:geolocator/geolocator.dart';

/// Sealed class representing the AR camera state.
///
/// Provides exhaustive pattern matching for different camera states.
sealed class ArCameraState {
  const ArCameraState();
}

/// Camera is initializing.
final class ArCameraInitializing extends ArCameraState {
  const ArCameraInitializing();
}

/// Camera is ready with FOV data.
final class ArCameraReady extends ArCameraState {
  final double hFov;
  final double vFov;
  final double hPixelPerDegree;
  final double vPixelPerDegree;

  const ArCameraReady({
    required this.hFov,
    required this.vFov,
    required this.hPixelPerDegree,
    required this.vPixelPerDegree,
  });
}

/// Camera encountered an error.
final class ArCameraError extends ArCameraState {
  final String message;
  final Object? error;

  const ArCameraError(this.message, [this.error]);
}

/// Singleton class storing calculated AR status and FOV information.
///
/// Maintains the current state of AR calculations for the session.
final class ArStatus {
  static final ArStatus _instance = ArStatus._internal();

  /// Horizontal field of view of the device in degrees.
  double hFov = 0;

  /// Vertical field of view of the device in degrees.
  double vFov = 0;

  /// Pixels per degree horizontally.
  double hPixelPerDegree = 0;

  /// Pixels per degree vertically.
  double vPixelPerDegree = 0;

  /// Current device heading in degrees.
  double heading = 0;

  /// Current device pitch in degrees.
  double pitch = 0;

  /// Current user location.
  Position? userLocation;

  /// Current camera state.
  ArCameraState cameraState = const ArCameraInitializing();

  factory ArStatus() => _instance;

  ArStatus._internal();

  /// Updates FOV values and calculates pixels per degree.
  void updateFov({
    required double hFov,
    required double vFov,
    required double screenWidth,
    required double screenHeight,
  }) {
    this.hFov = hFov;
    this.vFov = vFov;
    hPixelPerDegree = hFov > 0 ? (screenWidth / hFov) : 0;
    vPixelPerDegree = vFov > 0 ? (screenHeight / vFov) : 0;

    cameraState = ArCameraReady(
      hFov: hFov,
      vFov: vFov,
      hPixelPerDegree: hPixelPerDegree,
      vPixelPerDegree: vPixelPerDegree,
    );
  }

  /// Checks if the AR status has valid FOV data.
  bool get hasValidFov => hFov > 0 && vFov > 0;

  /// Checks if user location is available.
  bool get hasUserLocation => userLocation != null;

  /// Resets all values to defaults.
  void reset() {
    hFov = 0;
    vFov = 0;
    hPixelPerDegree = 0;
    vPixelPerDegree = 0;
    heading = 0;
    pitch = 0;
    userLocation = null;
    cameraState = const ArCameraInitializing();
  }

  @override
  String toString() => 'ArStatus('
      'hFov: $hFov, vFov: $vFov, '
      'heading: $heading, pitch: $pitch, '
      'userLocation: $userLocation, '
      'cameraState: $cameraState)';
}
