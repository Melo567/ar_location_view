import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class ArSensor {
  /// Direction the back camera points to, in degrees from true north,
  /// in `[0, 360)`.
  final double heading;

  /// Elevation of the camera axis in degrees: 0 when the device is held
  /// upright, negative when the camera points down.
  final double pitch;
  final Position? location;
  final NativeDeviceOrientation orientation;

  /// Estimated heading error in degrees (±), or -1 when unknown, e.g. while
  /// the compass needs calibration. On Android this is an approximation
  /// derived from the sensor accuracy status.
  final double compassAccuracy;

  /// Full device attitude as a row-major 3x3 rotation matrix mapping a
  /// world vector (East, North, Up — true north) to screen coordinates
  /// (x to the right of the screen, y to its top, z out of the screen
  /// towards the viewer), for the current UI orientation.
  ///
  /// Unlike [heading]/[pitch] it also carries the roll and has no
  /// singularity when tilting the device. When null (e.g. custom
  /// [ArSensorSource]), it is rebuilt from [heading] and [pitch] with no
  /// roll.
  final List<double>? rotationMatrix;

  const ArSensor({
    required this.heading,
    required this.pitch,
    required this.orientation,
    required this.compassAccuracy,
    this.location,
    this.rotationMatrix,
  });
}
