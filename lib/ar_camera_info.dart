import 'package:flutter/services.dart';

/// Reads the back camera's optical characteristics from the platform.
class ArCameraInfo {
  const ArCameraInfo._();

  static const MethodChannel _channel =
      MethodChannel('pie/ar_view_location/camera');

  /// Field of view of the back camera along its long side, in degrees, or
  /// null when it cannot be determined.
  static Future<double?> backCameraFieldOfView() async {
    try {
      final fov = await _channel.invokeMethod<double>('backCameraFieldOfView');
      return fov != null && fov > 0 && fov < 180 ? fov : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
