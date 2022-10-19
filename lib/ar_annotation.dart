import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

abstract class ArAnnotation {
  ArAnnotation({
    required this.uid,
    required this.position,
    this.azimuth = 0,
    this.distanceFromUser = 0,
    this.isVisible = false,
    this.arPosition = const Offset(0, 0),
    this.arPositionOffset = const Offset(0, 0),
  });

  String uid;
  Position position;
  double azimuth;
  double distanceFromUser;
  bool isVisible;
  Offset arPosition;
  Offset arPositionOffset;

  @override
  String toString() {
    return 'Annotation{position: $position, azimuth: $azimuth, distanceFromUser: $distanceFromUser, isVisible: $isVisible, arPosition: $arPosition}';
  }
}
