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
  }) : super(key: key);

  ///List of POI
  final List<ArAnnotation> annotations;

  ///widget
  final AnnotationViewBuilder annotationViewBuilder;

  ///ArAnnotation width
  final double annotationWidth;

  ///ArAnnotation height
  final double annotationHeight;

  ///Max distance marker visible
  final double maxVisibleDistance;

  final Size? frame;

  ///Callback when location change
  final ChangeLocationCallback onLocationChange;

  ///Show debug info sensor in debug mode
  final bool showDebugInfoSensor;

  ///Padding whew marker overlap
  final double paddingOverlap;

  ///Offset overlap y
  final double? yOffsetOverlap;

  ///accessory
  final Widget? accessory;

  ///Minimun distance reload
  final double minDistanceReload;

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
          ),
        if (widget.accessory != null) widget.accessory!
      ],
    );
  }
}

