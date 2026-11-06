import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// A point of interest shown by [ArView]. Extend it with your own data.
///
/// Only [uid] and [position] are inputs: the other fields are computed and
/// updated in place by the layout on every frame.
abstract class ArAnnotation {
  ArAnnotation({
    required this.uid,
    required this.position,
    this.azimuth = 0,
    this.distanceFromUser = 0,
    this.isVisible = false,
    this.arPosition = const Offset(0, 0),
    this.arPositionOffset = const Offset(0, 0),
    this.arScale = 1,
  });

  /// Unique identifier, used to keep the label's state across frames.
  String uid;

  /// Location of the POI. Its altitude is only used with
  /// [AnnotationLayoutConfig.useAltitude].
  Position position;

  /// Bearing from the user to the POI, in degrees from true north.
  double azimuth;

  /// Distance from the user, in meters.
  double distanceFromUser;

  /// Whether the label is currently on screen (false when grouped into
  /// another label, see [AnnotationLayoutResult.groups]).
  bool isVisible;

  /// Top-left corner of the label in the view's coordinates, before
  /// [arPositionOffset].
  Offset arPosition;

  /// Vertical shift of the label stacked above overlapping ones.
  Offset arPositionOffset;

  /// Scale of the label, set by the layout (see
  /// [AnnotationLayoutConfig.scaleWithDistance]). The label is scaled around
  /// its center.
  double arScale;

  @override
  String toString() {
    return 'Annotation{position: $position, azimuth: $azimuth, distanceFromUser: $distanceFromUser, isVisible: $isVisible, arPosition: $arPosition}';
  }
}
