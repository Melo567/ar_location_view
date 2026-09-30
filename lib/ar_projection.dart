import 'dart:math';
import 'dart:ui';

import 'ar_extension.dart';

/// Row-major 3x3 rotation matrix helpers for [ArSensor.rotationMatrix]
/// (world East/North/Up → screen x right / y up / z towards the viewer).
class ArRotation {
  const ArRotation._();

  /// Rebuilds the attitude from a heading and a pitch (degrees), assuming
  /// no roll. Used when a sensor source provides no rotation matrix.
  static List<double> fromHeadingPitch(double heading, double pitch) {
    final h = heading.toRadians;
    final p = pitch.toRadians;
    // Camera axis, and screen right which stays horizontal (no roll).
    final forward = [sin(h) * cos(p), cos(h) * cos(p), sin(p)];
    final right = [cos(h), -sin(h), 0.0];
    // Screen z points towards the viewer, i.e. opposite to the camera, and
    // y = z × x keeps the frame right-handed.
    final z = [-forward[0], -forward[1], -forward[2]];
    final up = [
      z[1] * right[2] - z[2] * right[1],
      z[2] * right[0] - z[0] * right[2],
      z[0] * right[1] - z[1] * right[0],
    ];
    return [...right, ...up, ...z];
  }

  /// Direction of the back camera in world coordinates (East, North, Up):
  /// the opposite of the screen z axis, i.e. minus the matrix' third row.
  static List<double> cameraForward(List<double> m) => [-m[6], -m[7], -m[8]];

  /// Heading of the camera axis in degrees from true north, in `[0, 360)`.
  static double heading(List<double> m) {
    final f = cameraForward(m);
    return (atan2(f[0], f[1]).toDegrees + 360) % 360;
  }

  /// Elevation of the camera axis in degrees (negative when pointing down).
  static double pitch(List<double> m) {
    final f = cameraForward(m);
    return asin(f[2].clamp(-1.0, 1.0)).toDegrees;
  }

  static List<double> multiplyVector(List<double> m, List<double> v) => [
        m[0] * v[0] + m[1] * v[1] + m[2] * v[2],
        m[3] * v[0] + m[4] * v[1] + m[5] * v[2],
        m[6] * v[0] + m[7] * v[1] + m[8] * v[2],
      ];
}

/// Pinhole model of the camera preview as displayed on screen.
///
/// The preview covers the view (see `ArCamera`), so the focal length in
/// pixels is the larger of the ones implied by each screen axis: the other
/// axis is cropped.
class ArProjection {
  ArProjection({
    required this.width,
    required this.height,
    required double cameraFieldOfView,
    required double previewAspectRatio,
  }) : focalLength =
            _focalLength(width, height, cameraFieldOfView, previewAspectRatio);

  final double width;
  final double height;

  /// Focal length in logical pixels.
  final double focalLength;

  double get horizontalFieldOfView =>
      2 * atan(width / 2 / focalLength).toDegrees;

  double get verticalFieldOfView =>
      2 * atan(height / 2 / focalLength).toDegrees;

  /// [cameraFieldOfView] is along the sensor's long side, which is shown
  /// along the screen's long side; [previewAspectRatio] is long/short.
  static double _focalLength(double width, double height,
      double cameraFieldOfView, double previewAspectRatio) {
    final longSide = max(width, height);
    final shortSide = min(width, height);
    final tanLong = tan((cameraFieldOfView / 2).toRadians);
    final tanShort = tanLong / max(previewAspectRatio, 1);
    return max(longSide / 2 / tanLong, shortSide / 2 / tanShort);
  }

  /// Projects a world direction (East, North, Up) seen with the attitude
  /// [rotation] to a screen point, or null when it is behind the camera.
  Offset? project(List<double> rotation, List<double> worldDirection) {
    final v = ArRotation.multiplyVector(rotation, worldDirection);
    // The camera looks along -z: anything at z >= 0 is behind or beside it.
    final depth = -v[2];
    if (depth <= 1e-6) return null;
    return Offset(
      width / 2 + focalLength * v[0] / depth,
      height / 2 - focalLength * v[1] / depth,
    );
  }

  /// Unit world direction (East, North, Up) for an azimuth and an elevation
  /// in degrees.
  static List<double> direction(double azimuth, double elevation) {
    final a = azimuth.toRadians;
    final e = elevation.toRadians;
    return [sin(a) * cos(e), cos(a) * cos(e), sin(e)];
  }
}
