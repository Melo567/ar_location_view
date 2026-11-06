import 'package:geolocator/geolocator.dart';

/// Projection parameters of a layout, see `AnnotationLayoutResult.status`.
class ArStatus {
  ///Horizontal field of view of the displayed preview, in degrees.
  double hFov = 0;

  ///Vertical field of view of the displayed preview, in degrees.
  double vFov = 0;

  double hPixelPerDegree = 0;

  double vPixelPerDegree = 0;

  double heading = 0;

  double pitch = 0;

  Position? userLocation;
}
