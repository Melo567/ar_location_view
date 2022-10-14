import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

class ArSensor {
  final double heading;
  final double pitch;
  final Position? location;
  final NativeDeviceOrientation orientation;

  final double compassAccuracy;

  const ArSensor({
    required this.heading,
    required this.pitch,
    required this.orientation,
    required this.compassAccuracy,
    this.location,
  });
}
