import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'ar_location_view.dart';

/// Signature for a function that creates a widget for a given annotation.
typedef AnnotationViewBuilder = Widget Function(
  BuildContext context,
  ArAnnotation annotation,
);

/// Callback when user location changes.
typedef ChangeLocationCallback = void Function(Position position);

/// Main AR view widget that renders annotations in augmented reality.
///
/// Uses Dart 3 features including pattern matching and switch expressions.
class ArView extends StatefulWidget {
  const ArView({
    super.key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.frame,
    required this.onLocationChange,
    required this.minDistanceReload,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    this.scaleWithDistance = true,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
  });

  /// List of AR annotations to display.
  final List<ArAnnotation> annotations;

  /// Builder function for annotation views.
  final AnnotationViewBuilder annotationViewBuilder;

  /// Width of each annotation widget.
  final double annotationWidth;

  /// Height of each annotation widget.
  final double annotationHeight;

  /// Maximum distance (in meters) for visible annotations.
  final double maxVisibleDistance;

  /// Frame size for the AR view.
  final Size frame;

  /// Callback when user location changes.
  final ChangeLocationCallback onLocationChange;

  /// Show debug sensor information in debug mode.
  final bool showDebugInfoSensor;

  /// Padding between overlapping annotations.
  final double paddingOverlap;

  /// Y offset for overlapping annotations.
  final double? yOffsetOverlap;

  /// Minimum distance change (in meters) to trigger reload.
  final double minDistanceReload;

  /// Scale annotation view based on distance from user.
  final bool scaleWithDistance;

  /// Marker color in radar.
  final Color? markerColor;

  /// Background radar color.
  final Color? backgroundRadar;

  /// Radar position in view.
  final RadarPosition? radarPosition;

  /// Show radar in view.
  final bool showRadar;

  /// Radar width.
  final double? radarWidth;

  @override
  State<ArView> createState() => _ArViewState();
}

class _ArViewState extends State<ArView> {
  final ArStatus _arStatus = ArStatus();
  Position? _position;

  @override
  void initState() {
    super.initState();
    ArSensorManager.instance.init();
  }

  @override
  void dispose() {
    ArSensorManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return StreamBuilder<ArSensor>(
      stream: ArSensorManager.instance.arSensor,
      builder: (context, snapshot) {
        // Use pattern matching for snapshot handling
        return switch (snapshot) {
          AsyncSnapshot(hasData: true, data: final arSensor?)
              when arSensor.hasValidLocation =>
            _buildArView(context, arSensor, size),
          _ => _buildLoading(),
        };
      },
    );
  }

  Widget _buildArView(BuildContext context, ArSensor arSensor, Size size) {
    final deviceLocation = arSensor.location!;

    _calculateFOV(arSensor.orientation, size.width, size.height);
    _updatePosition(deviceLocation);

    final annotations = _filterAndSortArAnnotation(
      widget.annotations,
      arSensor,
      deviceLocation,
    );
    _transformAnnotation(annotations);

    final radarWidth = widget.radarWidth != null
        ? widget.radarWidth! * 2
        : size.width;

    return Stack(
      children: [
        if (kDebugMode && widget.showDebugInfoSensor)
          Positioned(
            bottom: 0,
            child: _buildDebugInfo(context, arSensor),
          ),
        Stack(
          children: [
            for (final annotation in annotations)
              Positioned(
                left: annotation.arPosition.dx,
                top: annotation.arPosition.dy + size.height * 0.5,
                child: Transform.translate(
                  offset: Offset(0, annotation.arPositionOffset.dy),
                  child: Transform.scale(
                    scale: _calculateScale(annotation),
                    child: SizedBox(
                      width: widget.annotationWidth,
                      height: widget.annotationHeight,
                      child: widget.annotationViewBuilder(context, annotation),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (widget.showRadar)
          _buildRadar(
            context,
            widget.radarPosition ?? RadarPosition.topLeft,
            arSensor.heading,
            radarWidth,
          ),
      ],
    );
  }

  double _calculateScale(ArAnnotation annotation) {
    if (!widget.scaleWithDistance) return 1.0;
    return 1 - (annotation.distanceFromUser / (widget.maxVisibleDistance + 280));
  }

  Widget _buildRadar(
    BuildContext context,
    RadarPosition position,
    double heading,
    double width,
  ) {
    final radar = Padding(
      padding: const EdgeInsets.all(8.0),
      child: CustomPaint(
        size: Size(width / 2, width / 2),
        painter: RadarPainter(
          maxDistance: widget.maxVisibleDistance,
          arAnnotations: widget.annotations,
          heading: heading,
          background: widget.backgroundRadar ?? Colors.grey,
          markerColor: widget.markerColor ?? Colors.red,
        ),
      ),
    );

    final screenWidth = MediaQuery.sizeOf(context).width;

    // Use switch expression for cleaner positioning
    return switch (position) {
      RadarPosition.topCenter => Positioned(
          top: 0,
          left: screenWidth / 2 - width / 4,
          child: radar,
        ),
      RadarPosition.topRight => Positioned(
          top: 0,
          right: 0,
          child: radar,
        ),
      RadarPosition.bottomLeft => Positioned(
          bottom: 0,
          left: 0,
          child: radar,
        ),
      RadarPosition.bottomCenter => Positioned(
          bottom: 0,
          left: screenWidth / 2 - width / 4,
          child: radar,
        ),
      RadarPosition.bottomRight => Positioned(
          bottom: 0,
          right: 0,
          child: radar,
        ),
      RadarPosition.topLeft => Positioned(
          top: 0,
          left: 0,
          child: radar,
        ),
    };
  }

  Widget _buildDebugInfo(BuildContext context, ArSensor arSensor) {
    return Container(
      color: Colors.white,
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Latitude  : ${arSensor.location?.latitude}'),
          Text('Longitude : ${arSensor.location?.longitude}'),
          Text('Pitch     : ${arSensor.pitch.toStringAsFixed(2)}'),
          Text('Heading   : ${arSensor.heading.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void _calculateFOV(
    NativeDeviceOrientation orientation,
    double width,
    double height,
  ) {
    const baseFov = 58.0;

    final (hFov, vFov) = switch (orientation) {
      NativeDeviceOrientation.landscapeLeft ||
      NativeDeviceOrientation.landscapeRight =>
        (baseFov, (2 * atan(tan((baseFov / 2).toRadians) * (height / width))).toDegrees),
      _ => (
          (2 * atan(tan((baseFov / 2).toRadians) * (width / height))).toDegrees,
          baseFov,
        ),
    };

    _arStatus.hFov = hFov;
    _arStatus.vFov = vFov;
    _arStatus.hPixelPerDegree = hFov > 0 ? (width / hFov) : 0;
    _arStatus.vPixelPerDegree = vFov > 0 ? (height / vFov) : 0;
  }

  List<ArAnnotation> _visibleAnnotations(
    List<ArAnnotation> annotations,
    double heading,
  ) {
    final degreesDeltaH = _arStatus.hFov;

    return annotations.where((annotation) {
      final delta = ArMath.deltaAngle(heading, annotation.azimuth);
      final isVisible = delta.abs() < degreesDeltaH;
      annotation.isVisible = isVisible;
      return isVisible;
    }).toList();
  }

  List<ArAnnotation> _calculateDistanceAndBearingFromUser(
    List<ArAnnotation> annotations,
    Position deviceLocation,
    ArSensor arSensor,
  ) {
    for (final annotation in annotations) {
      final annotationLocation = annotation.position;

      annotation.azimuth = Geolocator.bearingBetween(
        deviceLocation.latitude,
        deviceLocation.longitude,
        annotationLocation.latitude,
        annotationLocation.longitude,
      );

      annotation.distanceFromUser = Geolocator.distanceBetween(
        deviceLocation.latitude,
        deviceLocation.longitude,
        annotationLocation.latitude,
        annotationLocation.longitude,
      );

      final dy = arSensor.pitch * _arStatus.vPixelPerDegree;
      final dx = ArMath.deltaAngle(annotation.azimuth, arSensor.heading) *
          _arStatus.hPixelPerDegree;

      annotation.arPosition = Offset(dx, dy);
    }

    return annotations;
  }

  List<ArAnnotation> _filterAndSortArAnnotation(
    List<ArAnnotation> annotations,
    ArSensor arSensor,
    Position deviceLocation,
  ) {
    _calculateDistanceAndBearingFromUser(annotations, deviceLocation, arSensor);

    final filtered = annotations
        .where((e) => e.distanceFromUser < widget.maxVisibleDistance)
        .toList();

    return _visibleAnnotations(filtered, arSensor.heading);
  }

  void _transformAnnotation(List<ArAnnotation> annotations) {
    // Sort by distance (closest first)
    annotations.sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    for (final annotation in annotations) {
      for (final other in annotations) {
        if (annotation.uid == other.uid) break;

        if (annotation.overlapsHorizontally(other, widget.annotationWidth)) {
          annotation.arPositionOffset = Offset(
            0,
            other.arPositionOffset.dy -
                ((widget.yOffsetOverlap ?? widget.annotationHeight) +
                    widget.paddingOverlap),
          );
        }
      }
    }
  }

  void _updatePosition(Position newPosition) {
    if (_position case null) {
      widget.onLocationChange(newPosition);
      _position = newPosition;
      return;
    }

    final distance = Geolocator.distanceBetween(
      _position!.latitude,
      _position!.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    if (distance > widget.minDistanceReload) {
      widget.onLocationChange(newPosition);
      _position = newPosition;
    }
  }
}
