import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import 'ar_location_view.dart';

/// Signature for a function that creates a widget for a given annotation,
typedef AnnotationViewBuilder = Widget Function(
    BuildContext context, ArAnnotation annotation);

typedef ChangeLocationCallback = void Function(Position position);

class ArView extends StatefulWidget {
  const ArView({
    Key? key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.frame,
    required this.onLocationChange,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    required this.minDistanceReload,
  }) : super(key: key);

  final List<ArAnnotation> annotations;
  final AnnotationViewBuilder annotationViewBuilder;
  final double annotationWidth;
  final double annotationHeight;

  final double maxVisibleDistance;

  final Size frame;

  final ChangeLocationCallback onLocationChange;

  final bool showDebugInfoSensor;

  final double paddingOverlap;
  final double? yOffsetOverlap;
  final double minDistanceReload;

  @override
  State<ArView> createState() => _ArViewState();
}

class _ArViewState extends State<ArView> {
  ArStatus arStatus = ArStatus();

  Position? position;

  @override
  void initState() {
    ArSensorManager.instance.init();
    super.initState();
  }

  @override
  void dispose() {
    ArSensorManager.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    return StreamBuilder(
      stream: ArSensorManager.instance.arSensor,
      builder: (context, data) {
        if (data.hasData) {
          if (data.data != null) {
            final arSensor = data.data!;
            if (arSensor.location == null) {
              return loading();
            }
            _calculateFOV(arSensor.orientation, width, height);
            _updatePosition(arSensor.location!);
            final deviceLocation = arSensor.location!;
            final annotations = _filterAndSortArAnnotation(
                widget.annotations, arSensor, deviceLocation);
            _transformAnnotation(annotations);
            return Stack(
              children: [
                if (kDebugMode && widget.showDebugInfoSensor)
                  Positioned(
                    bottom: 0,
                    child: debugInfo(context, arSensor),
                  ),
                Stack(
                    children: annotations.map(
                  (e) {
                    return Positioned(
                      left: e.arPosition.dx,
                      top: e.arPosition.dy + height * 0.5,
                      child: Transform.translate(
                        offset: Offset(0, e.arPositionOffset.dy),
                        child: SizedBox(
                          width: widget.annotationWidth,
                          height: widget.annotationHeight,
                          child: widget.annotationViewBuilder(context, e),
                        ),
                      ),
                    );
                  },
                ).toList()),
              ],
            );
          }
        }
        return loading();
      },
    );
  }

  Widget debugInfo(BuildContext context, ArSensor? arSensor) {
    return Container(
      color: Colors.white,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitude  : ${arSensor?.location?.latitude}'),
            Text('Longitude : ${arSensor?.location?.longitude}'),
            Text('Pitch     : ${arSensor?.pitch}'),
            Text('Heading   : ${arSensor?.heading}'),
          ],
        ),
      ),
    );
  }

  Widget loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void _calculateFOV(
      NativeDeviceOrientation orientation, double width, double height) {
    double hFov = 0;
    double vFov = 0;
    const tempFOv = 58.0;

    if (orientation == NativeDeviceOrientation.landscapeLeft ||
        orientation == NativeDeviceOrientation.landscapeRight) {
      hFov = tempFOv;
      vFov = (2 * atan(tan((hFov / 2).toRadians) * (height / width))).toDegrees;
    } else {
      vFov = tempFOv;
      hFov = (2 * atan(tan((vFov / 2).toRadians) * (width / height))).toDegrees;
    }
    arStatus.hFov = hFov;
    arStatus.vFov = vFov;
    arStatus.hPixelPerDegree = hFov > 0 ? (width / hFov) : 0;
    arStatus.vPixelPerDegree = vFov > 0 ? (height / vFov) : 0;
  }

  List<ArAnnotation> _visibleAnnotations(
      List<ArAnnotation> annotations, double heading) {
    final degreesDeltaH = arStatus.hFov;
    return annotations.where((ArAnnotation annotation) {
      final delta = ArMath.deltaAngle(heading, annotation.azimuth);
      final isVisible = delta.abs() < degreesDeltaH;
      annotation.isVisible = isVisible;
      return annotation.isVisible;
    }).toList();
  }

  List<ArAnnotation> _calculateDistanceAndBearingFromUser(
      List<ArAnnotation> annotations,
      Position deviceLocation,
      ArSensor arSensor) {
    return annotations.map((e) {
      final annotationLocation = e.position;
      e.azimuth = Geolocator.bearingBetween(
        deviceLocation.latitude,
        deviceLocation.longitude,
        annotationLocation.latitude,
        annotationLocation.longitude,
      );
      e.distanceFromUser = Geolocator.distanceBetween(
          deviceLocation.latitude,
          deviceLocation.longitude,
          annotationLocation.latitude,
          annotationLocation.longitude);
      final dy = arSensor.pitch * arStatus.vPixelPerDegree;
      final dx = ArMath.deltaAngle(e.azimuth, arSensor.heading) *
          arStatus.hPixelPerDegree;
      e.arPosition = Offset(dx, dy);
      return e;
    }).toList();
  }

  List<ArAnnotation> _filterAndSortArAnnotation(List<ArAnnotation> annotations,
      ArSensor arSensor, Position deviceLocation) {
    List<ArAnnotation> temps = _calculateDistanceAndBearingFromUser(
        annotations, deviceLocation, arSensor);
    temps = annotations
        .where(
            (element) => element.distanceFromUser < widget.maxVisibleDistance)
        .toList();
    temps = _visibleAnnotations(temps, arSensor.heading);
    return temps;
  }

  void _transformAnnotation(List<ArAnnotation> annotations) {
    annotations.sort((a, b) => (a.distanceFromUser < b.distanceFromUser)
        ? -1
        : ((a.distanceFromUser > b.distanceFromUser) ? 1 : 0));

    for (final ArAnnotation annotation in annotations) {
      var i = 0;
      while (i < annotations.length) {
        final annotation2 = annotations[i];
        if (annotation.uid == annotation2.uid) {
          break;
        }
        final collision =
            intersects(annotation, annotation2, widget.annotationWidth);
        if (collision) {
          annotation.arPositionOffset = Offset(
              0,
              annotation2.arPositionOffset.dy -
                  ((widget.yOffsetOverlap ?? widget.annotationHeight) +
                      widget.paddingOverlap));
        }
        i++;
      }
    }
  }

  bool intersects(
      ArAnnotation annotation1, ArAnnotation annotation2, double width) {
    return (annotation2.arPosition.dx >= annotation1.arPosition.dx &&
            annotation2.arPosition.dx <= (annotation1.arPosition.dx + width)) ||
        (annotation1.arPosition.dx >= annotation2.arPosition.dx &&
            annotation1.arPosition.dx <= (annotation2.arPosition.dx + width));
  }

  void _updatePosition(Position newPosition) {
    if (position == null) {
      widget.onLocationChange(newPosition);
      position = newPosition;
    } else {
      final distance = Geolocator.distanceBetween(position!.latitude,
          position!.longitude, newPosition.latitude, newPosition.longitude);
      if (distance > widget.minDistanceReload) {
        widget.onLocationChange(newPosition);
        widget.onLocationChange(newPosition);
        position = newPosition;
      }
    }
  }
}
