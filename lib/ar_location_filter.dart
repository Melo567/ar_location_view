import 'dart:math';

import 'package:geolocator/geolocator.dart';

/// Kalman filter smoothing GPS fixes according to their reported accuracy.
///
/// Raw fixes jump by ±10–20 m, which swings the bearing of nearby POIs by
/// tens of degrees. Each fix is weighted by its accuracy against the
/// uncertainty of the current estimate, which grows with time at
/// [processNoise] (the expected user speed): an imprecise fix barely moves
/// the estimate, a precise one or a long gap lets it follow the user.
class LocationFilter {
  LocationFilter({this.processNoise = 3});

  /// Expected speed of the user, in meters per second.
  final double processNoise;

  final _horizontal = _ScalarKalman();
  final _altitude = _ScalarKalman();

  Position? _estimate;

  Position? get estimate => _estimate;

  Position add(Position fix) {
    final previous = _estimate;
    final horizontalAccuracy = max(fix.accuracy, 1.0);
    if (previous == null) {
      _horizontal.reset(horizontalAccuracy, fix.timestamp);
      _altitude.reset(max(fix.altitudeAccuracy, 1.0), fix.timestamp);
      return _estimate = fix;
    }

    final gain =
        _horizontal.update(horizontalAccuracy, fix.timestamp, processNoise);
    // A zero altitude accuracy means "unknown": keep the altitude estimate.
    final altitudeGain = fix.altitudeAccuracy > 0
        ? _altitude.update(fix.altitudeAccuracy, fix.timestamp, processNoise)
        : 0.0;

    return _estimate = Position(
      latitude: previous.latitude + gain * (fix.latitude - previous.latitude),
      longitude:
          previous.longitude + gain * (fix.longitude - previous.longitude),
      timestamp: fix.timestamp,
      accuracy: _horizontal.accuracy,
      altitude:
          previous.altitude + altitudeGain * (fix.altitude - previous.altitude),
      altitudeAccuracy: fix.altitudeAccuracy > 0
          ? _altitude.accuracy
          : previous.altitudeAccuracy,
      heading: fix.heading,
      headingAccuracy: fix.headingAccuracy,
      speed: fix.speed,
      speedAccuracy: fix.speedAccuracy,
      floor: fix.floor,
      isMocked: fix.isMocked,
    );
  }

  void reset() => _estimate = null;
}

/// Variance bookkeeping of a 1D Kalman filter whose state is updated by the
/// caller with the returned gain.
class _ScalarKalman {
  double _variance = 0;
  DateTime? _time;

  double get accuracy => sqrt(_variance);

  void reset(double accuracy, DateTime time) {
    _variance = accuracy * accuracy;
    _time = time;
  }

  double update(double accuracy, DateTime time, double processNoise) {
    final last = _time;
    if (last != null && time.isAfter(last)) {
      final dt = time.difference(last).inMicroseconds / 1e6;
      _variance += dt * processNoise * processNoise;
    }
    _time = time;
    final gain = _variance / (_variance + accuracy * accuracy);
    _variance = (1 - gain) * _variance;
    return gain;
  }
}
