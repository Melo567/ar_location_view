import 'ar_sensor.dart';

/// Source of fused sensor + location samples consumed by [ArView].
///
/// [ArSensorManager] is the default, device-backed implementation. Provide
/// your own implementation (e.g. a fake/test double) via [ArView.sensorSource]
/// to avoid depending on real hardware.
///
/// [ArView] never disposes a source it did not create: when you pass one
/// via [ArView.sensorSource], you own it and must call [dispose] yourself.
abstract class ArSensorSource {
  /// Starts listening to the underlying sensors and location updates.
  ///
  /// Every [ArView] using this source calls it, so it must be idempotent
  /// when the source is shared between several views.
  void init();

  /// Stream of fused sensor samples. Must be a broadcast stream if the
  /// source is shared between several views. Failures (e.g. permission
  /// denied) are reported as [ArSensorException] stream errors.
  Stream<ArSensor> get arSensor;

  /// Stops listening and releases resources.
  void dispose();
}
