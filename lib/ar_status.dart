import 'package:geolocator/geolocator.dart';

class ArStatus {
  static final ArStatus _instance = ArStatus._internal();

  ///Champ de vision horizontal de l'appareil.
  double hFov = 0;

  ///champ de vision vertical de l'appareil
  double vFov = 0;

  double hPixelPerDegree = 0;

  double vPixelPerDegree = 0;

  double heading = 0;

  double pitch = 0;

  Position? userLocation;

  factory ArStatus() {
    return _instance;
  }

  ArStatus._internal();
}
