import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Base class for AR annotations (Points of Interest).
///
/// This is a base class that should be extended to create custom annotations.
/// Uses Dart 3 class modifiers for proper inheritance control.
base class ArAnnotation {
  ArAnnotation({
    required this.uid,
    required this.position,
    this.azimuth = 0,
    this.distanceFromUser = 0,
    this.isVisible = false,
    this.arPosition = Offset.zero,
    this.arPositionOffset = Offset.zero,
  });

  /// Unique identifier for the annotation.
  final String uid;

  /// GPS position of the annotation.
  final Position position;

  /// Bearing from user to annotation in degrees (0-360).
  double azimuth;

  /// Distance from user to annotation in meters.
  double distanceFromUser;

  /// Whether the annotation is currently visible in the camera view.
  bool isVisible;

  /// 2D position on screen relative to center.
  Offset arPosition;

  /// Offset for collision avoidance (vertical stacking).
  Offset arPositionOffset;

  /// Creates a copy with optionally updated mutable values.
  void updatePosition({
    double? azimuth,
    double? distanceFromUser,
    bool? isVisible,
    Offset? arPosition,
    Offset? arPositionOffset,
  }) {
    if (azimuth != null) this.azimuth = azimuth;
    if (distanceFromUser != null) this.distanceFromUser = distanceFromUser;
    if (isVisible != null) this.isVisible = isVisible;
    if (arPosition != null) this.arPosition = arPosition;
    if (arPositionOffset != null) this.arPositionOffset = arPositionOffset;
  }

  /// Resets the AR position data.
  void resetArPosition() {
    arPosition = Offset.zero;
    arPositionOffset = Offset.zero;
    isVisible = false;
  }

  /// Checks if two annotations overlap horizontally.
  bool overlapsHorizontally(ArAnnotation other, double width) {
    final myLeft = arPosition.dx;
    final myRight = arPosition.dx + width;
    final otherLeft = other.arPosition.dx;
    final otherRight = other.arPosition.dx + width;

    return (otherLeft >= myLeft && otherLeft <= myRight) ||
        (myLeft >= otherLeft && myLeft <= otherRight);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArAnnotation &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;

  @override
  String toString() => 'ArAnnotation('
      'uid: $uid, '
      'position: $position, '
      'azimuth: $azimuth, '
      'distanceFromUser: $distanceFromUser, '
      'isVisible: $isVisible, '
      'arPosition: $arPosition)';
}
