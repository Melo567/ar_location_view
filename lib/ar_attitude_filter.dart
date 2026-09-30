import 'dart:math';

import 'ar_extension.dart';

/// Adaptive, time-based low-pass filter for [ArSensor.rotationMatrix].
///
/// Compass jitter makes labels shake while the device is held still, but a
/// strong fixed smoothing makes them lag behind when the user turns. The
/// smoothing is therefore relaxed with the rotation between two samples:
/// full [timeConstant] when still, none from [fastRotationDegrees] on.
class AttitudeFilter {
  AttitudeFilter({this.timeConstant = 0.25, this.fastRotationDegrees = 10});

  /// Smoothing time constant, in seconds, while the device is still.
  final double timeConstant;

  /// Rotation between two samples, in degrees, above which the attitude is
  /// followed without smoothing.
  final double fastRotationDegrees;

  List<double>? _value;
  double? _lastTime;

  /// Filters [matrix], sampled at [timeSeconds] (any monotonic clock).
  List<double> add(List<double> matrix, double timeSeconds) {
    final previous = _value;
    final lastTime = _lastTime;
    _lastTime = timeSeconds;
    if (previous == null || lastTime == null) {
      return _value = List<double>.of(matrix);
    }

    final dt = (timeSeconds - lastTime).clamp(0.0, 1.0);
    final motion =
        (angleBetween(previous, matrix) / fastRotationDegrees).clamp(0.0, 1.0);
    final tau = timeConstant * (1 - motion);
    final alpha = tau <= 0 ? 1.0 : 1 - exp(-dt / tau);

    final blended = List<double>.generate(
        9, (i) => previous[i] + alpha * (matrix[i] - previous[i]));
    return _value = orthonormalize(blended);
  }

  void reset() {
    _value = null;
    _lastTime = null;
  }

  /// Angle, in degrees, of the rotation between two rotation matrices.
  static double angleBetween(List<double> a, List<double> b) {
    // trace(A · Bᵀ) = 1 + 2·cos(θ)
    var trace = 0.0;
    for (var i = 0; i < 9; i++) {
      trace += a[i] * b[i];
    }
    return acos(((trace - 1) / 2).clamp(-1.0, 1.0)).toDegrees;
  }

  /// Blending rotation matrices element-wise slightly breaks their
  /// orthonormality: rebuild a proper rotation from the rows (Gram–Schmidt).
  static List<double> orthonormalize(List<double> m) {
    final x = _normalize([m[0], m[1], m[2]]);
    final yRaw = [m[3], m[4], m[5]];
    final dot = x[0] * yRaw[0] + x[1] * yRaw[1] + x[2] * yRaw[2];
    final y = _normalize(
        [yRaw[0] - dot * x[0], yRaw[1] - dot * x[1], yRaw[2] - dot * x[2]]);
    final z = [
      x[1] * y[2] - x[2] * y[1],
      x[2] * y[0] - x[0] * y[2],
      x[0] * y[1] - x[1] * y[0],
    ];
    return [...x, ...y, ...z];
  }

  static List<double> _normalize(List<double> v) {
    final length = sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
    if (length == 0) return v;
    return [v[0] / length, v[1] / length, v[2] / length];
  }
}

/// Same adaptive smoothing as [AttitudeFilter] for a heading alone, used
/// when the platform provides no rotation matrix. Handles the 359° → 0°
/// wrap-around, which a plain low-pass filter would average to 180°.
class HeadingFilter {
  HeadingFilter({this.timeConstant = 0.25, this.fastRotationDegrees = 10});

  final double timeConstant;
  final double fastRotationDegrees;

  double? _value;
  double? _lastTime;

  /// Filters [heading] (degrees), sampled at [timeSeconds]. Returns a value
  /// in `[0, 360)`.
  double add(double heading, double timeSeconds) {
    final previous = _value;
    final lastTime = _lastTime;
    _lastTime = timeSeconds;
    if (previous == null || lastTime == null) {
      return _value = heading % 360;
    }

    final delta = (heading - previous + 540) % 360 - 180;
    final dt = (timeSeconds - lastTime).clamp(0.0, 1.0);
    final motion = (delta.abs() / fastRotationDegrees).clamp(0.0, 1.0);
    final tau = timeConstant * (1 - motion);
    final alpha = tau <= 0 ? 1.0 : 1 - exp(-dt / tau);
    return _value = (previous + alpha * delta + 360) % 360;
  }

  void reset() {
    _value = null;
    _lastTime = null;
  }
}
