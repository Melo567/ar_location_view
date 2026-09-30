import 'package:flutter/material.dart';

import 'ar_location_view.dart';

class ArLocationWidget extends StatefulWidget {
  const ArLocationWidget({
    super.key,
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
    this.minScale = AnnotationLayoutConfig.defaultMinScale,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
    this.isLoading = false,
    this.loadingWidget,
    this.sensorSource,
    this.sensorErrorBuilder,
    this.cameraFieldOfView,
    this.useAltitude = false,
    this.hideWithinLocationAccuracy = false,
    this.maxRows,
    this.groupBadgeBuilder,
  });

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

  ///Scale of a label at [maxVisibleDistance] when [scaleWithDistance]: labels
  ///shrink linearly from 1 next to the user down to this value.
  final double minScale;

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

  final bool isLoading;

  final Widget? loadingWidget;

  ///Source of fused sensor/location samples, forwarded to [ArView].
  ///Defaults to a device-backed [ArSensorManager] instantiated per view.
  final ArSensorSource? sensorSource;

  ///Widget shown when location/sensors are unavailable, forwarded to
  ///[ArView].
  final ArSensorErrorBuilder? sensorErrorBuilder;

  ///Field of view of the back camera along its long side, in degrees.
  ///Read from the device when null.
  final double? cameraFieldOfView;

  ///Place POIs above/below the horizon from their altitude, see
  ///[AnnotationLayoutConfig.useAltitude].
  final bool useAltitude;

  ///Hide POIs closer than the location accuracy, see
  ///[AnnotationLayoutConfig.hideWithinLocationAccuracy].
  final bool hideWithinLocationAccuracy;

  ///Maximum number of stacked rows of labels, see
  ///[AnnotationLayoutConfig.maxRows].
  final int? maxRows;

  ///Badge shown on a label that has annotations grouped into it, see
  ///[ArView.groupBadgeBuilder].
  final AnnotationGroupBadgeBuilder? groupBadgeBuilder;

  @override
  State<ArLocationWidget> createState() => _ArLocationWidgetState();
}

class _ArLocationWidgetState extends State<ArLocationWidget> {
  bool initCam = false;
  double? previewAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ArCamera(
          onCameraError: (String error) {
            initCam = false;
            setState(() {});
          },
          onPreviewAspectRatio: (double aspectRatio) {
            previewAspectRatio = aspectRatio;
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
            minScale: widget.minScale,
            markerColor: widget.markerColor,
            backgroundRadar: widget.backgroundRadar,
            radarPosition: widget.radarPosition,
            showRadar: widget.showRadar,
            radarWidth: widget.radarWidth,
            sensorSource: widget.sensorSource,
            sensorErrorBuilder: widget.sensorErrorBuilder,
            cameraFieldOfView: widget.cameraFieldOfView,
            previewAspectRatio: previewAspectRatio,
            useAltitude: widget.useAltitude,
            hideWithinLocationAccuracy: widget.hideWithinLocationAccuracy,
            maxRows: widget.maxRows,
            groupBadgeBuilder: widget.groupBadgeBuilder,
          ),
        if (initCam && widget.accessory != null) widget.accessory!,
        if (widget.isLoading)
          if (widget.loadingWidget == null)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            widget.loadingWidget!
      ],
    );
  }
}
