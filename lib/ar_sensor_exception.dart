enum ArSensorErrorType {
  /// Location permission was denied; it may be requested again.
  permissionDenied,

  /// Location permission was permanently denied; the user must enable it
  /// from the system settings (see `openAppSettings()` in
  /// `permission_handler`).
  permissionPermanentlyDenied,

  /// Location services (GPS) are disabled on the device.
  locationServiceDisabled,

  /// Any other error reported by the location or sensor streams.
  unknown,
}

/// Error emitted on [ArSensorSource.arSensor] when sensor or location data
/// cannot be provided.
class ArSensorException implements Exception {
  const ArSensorException(this.type, {this.cause});

  final ArSensorErrorType type;

  /// Underlying error, if any.
  final Object? cause;

  @override
  String toString() => 'ArSensorException($type, cause: $cause)';
}
