import 'package:flutter/material.dart';

import 'ar_location_view.dart';

class ArLocationWidget extends StatefulWidget {
  const ArLocationWidget({
    Key? key,
    required this.annotations,
    required this.annotationViewBuilder,
    required this.onLocationChange,
    this.annotationWidth = 200,
    this.annotationHeight = 75,
    this.maxVisibleDistance = 1500,
    this.frame,
    this.showDebugInfoSensor = true,
    this.paddingOverlap = 5,
    this.yOffsetOverlap,
    this.accessory,
    this.minDistanceReload = 50,
    this.scaleWithDistance = true,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
  }) : super(key: key);

  ///List of POIs
  final List<ArAnnotation> annotations;

  ///Function given context and annotation
  ///return widget for annotation view
  final AnnotationViewBuilder annotationViewBuilder;

  ///Annotation view width
  final double annotationWidth;

  ///Annotation view height
  final double annotationHeight;

  ///Max distance marker visible
  final double maxVisibleDistance;

  final Size? frame;

  ///Callback when location change
  final ChangeLocationCallback onLocationChange;

  ///Show debug info sensor in debug mode
  final bool showDebugInfoSensor;

  ///Padding when marker overlap
  final double paddingOverlap;

  ///Offset overlap y
  final double? yOffsetOverlap;

  ///accessory
  final Widget? accessory;

  ///Min distance reload
  final double minDistanceReload;

  ///Scale annotation view with distance from user
  final bool scaleWithDistance;

  /// marker color in radar
  final Color? markerColor;

  ///background radar color
  final Color? backgroundRadar;

  ///radar position in view
  final RadarPosition? radarPosition;

  ///Show radar in view
  final bool showRadar;

  ///Radar width
  final double? radarWidth;

  @override
  State<ArLocationWidget> createState() => _ArLocationWidgetState();
}

class _ArLocationWidgetState extends State<ArLocationWidget> {
  bool initCam = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ArCamera(
          onCameraError: (String error) {
            initCam = false;
            setState(() {});
          },
          onCameraSuccess: () {
            initCam = true;
            setState(() {});
          },
        ),
        if (initCam)
          ArView(
            annotations: widget.annotations,
            annotationViewBuilder: widget.annotationViewBuilder,
            frame: widget.frame ?? const Size(100, 75),
            onLocationChange: widget.onLocationChange,
            annotationWidth: widget.annotationWidth,
            annotationHeight: widget.annotationHeight,
            maxVisibleDistance: widget.maxVisibleDistance,
            showDebugInfoSensor: widget.showDebugInfoSensor,
            paddingOverlap: widget.paddingOverlap,
            yOffsetOverlap: widget.yOffsetOverlap,
            minDistanceReload: widget.minDistanceReload,
            scaleWithDistance: widget.scaleWithDistance,
            markerColor: widget.markerColor,
            backgroundRadar: widget.backgroundRadar,
            radarPosition: widget.radarPosition,
            showRadar: widget.showRadar,
            radarWidth: widget.radarWidth,
          ),
        if (initCam && widget.accessory != null) widget.accessory!
      ],
    );
  }
}
