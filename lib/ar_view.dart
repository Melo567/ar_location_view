import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'ar_location_view.dart';

/// Signature for a function that creates a widget for a given annotation.
///
/// [ArView] re-sorts and re-filters annotations on every sensor update, so
/// their position in the rendered list is not stable across frames. To keep
/// Flutter's element reconciliation correct despite that reordering, [ArView]
/// already wraps the returned widget in a [Positioned] keyed with
/// `ValueKey(annotation.uid)` — you do not need to (but may) key the widget
/// you return here yourself.
typedef AnnotationViewBuilder = Widget Function(
    BuildContext context, ArAnnotation annotation);

typedef ChangeLocationCallback = void Function(Position position);

/// Builds the badge shown on [annotation]'s label when [grouped] annotations
/// did not fit on screen and were grouped into it.
typedef AnnotationGroupBadgeBuilder = Widget Function(
    BuildContext context, ArAnnotation annotation, List<ArAnnotation> grouped);

/// Builds the widget shown instead of the AR overlay when no location is
/// available because the sensor source reported [error].
typedef ArSensorErrorBuilder = Widget Function(
    BuildContext context, ArSensorException error);

class ArView extends StatefulWidget {
  const ArView({
    super.key,
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
    this.scaleWithDistance = true,
    this.minScale = AnnotationLayoutConfig.defaultMinScale,
    this.markerColor,
    this.backgroundRadar,
    this.radarPosition,
    this.showRadar = true,
    this.radarWidth,
    this.sensorSource,
    this.sensorErrorBuilder,
    this.cameraFieldOfView,
    this.previewAspectRatio,
    this.useAltitude = false,
    this.hideWithinLocationAccuracy = false,
    this.rowAnimationDuration = const Duration(milliseconds: 200),
    this.maxRows,
    this.groupBadgeBuilder,
  });

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

  ///Scale annotation view with distance from user
  final bool scaleWithDistance;

  ///Scale of a label at [maxVisibleDistance] when [scaleWithDistance]: labels
  ///shrink linearly from 1 next to the user down to this value.
  final double minScale;

  ///Radar

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

  ///Source of fused sensor/location samples. Defaults to a device-backed
  ///[ArSensorManager] instantiated per [ArView]. Provide your own
  ///implementation (e.g. a fake source) to test without real hardware or
  ///to share a single sensor pipeline across multiple views. A provided
  ///source is not disposed by [ArView]: its owner must dispose it.
  final ArSensorSource? sensorSource;

  ///Widget shown when the sensor source reports an error (e.g. location
  ///permission denied) before any location is known. Defaults to a short
  ///message.
  final ArSensorErrorBuilder? sensorErrorBuilder;

  ///Field of view of the back camera along its long side, in degrees. When
  ///null, it is read from the device, falling back to
  ///[AnnotationLayoutConfig.defaultCameraFieldOfView].
  final double? cameraFieldOfView;

  ///Aspect ratio (long side / short side) of the camera preview shown behind
  ///this view. Defaults to [AnnotationLayoutConfig.defaultPreviewAspectRatio].
  final double? previewAspectRatio;

  ///Place POIs above/below the horizon from their altitude, see
  ///[AnnotationLayoutConfig.useAltitude].
  final bool useAltitude;

  ///Hide POIs closer than the location accuracy, see
  ///[AnnotationLayoutConfig.hideWithinLocationAccuracy].
  final bool hideWithinLocationAccuracy;

  ///Duration of the transition when a label moves to another overlap row.
  ///[Duration.zero] disables the animation.
  final Duration rowAnimationDuration;

  ///Maximum number of stacked rows of labels, see
  ///[AnnotationLayoutConfig.maxRows].
  final int? maxRows;

  ///Badge shown on a label that has annotations grouped into it. Defaults
  ///to a "+N" bubble on its top-right corner; return
  ///`const SizedBox.shrink()` to hide it.
  final AnnotationGroupBadgeBuilder? groupBadgeBuilder;

  @override
  State<ArView> createState() => _ArViewState();
}

class _ArViewState extends State<ArView> {
  late final bool _ownsSensorSource = widget.sensorSource == null;
  late final ArSensorSource _sensorSource =
      widget.sensorSource ?? ArSensorManager();

  final AnnotationLayoutEngine _layoutEngine = const AnnotationLayoutEngine();

  StreamSubscription<ArSensor>? _sensorSubscription;

  /// Latest sensor sample received. Updated only from [_onArSensor], never
  /// from [build], so effects (updating [position], notifying
  /// [ArView.onLocationChange]) never run as a side effect of building.
  ArSensor? _latestSensor;

  ArSensorException? _sensorError;

  Position? position;

  /// Field of view read from the device, used unless
  /// [ArView.cameraFieldOfView] overrides it.
  double? _deviceCameraFieldOfView;

  /// Overlap rows of the last layout, fed back to the next one so labels
  /// keep their row across frames. A cache of the layout, not UI state:
  /// updating it from [build] is harmless.
  Map<String, int> _rows = const {};

  final AnnotationGeoCache _geoCache = AnnotationGeoCache();

  @override
  void initState() {
    super.initState();
    if (widget.cameraFieldOfView == null) {
      _loadCameraFieldOfView();
    }
    _sensorSource.init();
    _sensorSubscription =
        _sensorSource.arSensor.listen(_onArSensor, onError: _onSensorError);
  }

  @override
  void dispose() {
    _sensorSubscription?.cancel();
    if (_ownsSensorSource) {
      _sensorSource.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCameraFieldOfView() async {
    final fov = await ArCameraInfo.backCameraFieldOfView();
    if (!mounted || fov == null) return;
    setState(() => _deviceCameraFieldOfView = fov);
  }

  void _onArSensor(ArSensor arSensor) {
    if (arSensor.location != null) {
      _updatePosition(arSensor.location!);
    }
    if (!mounted) return;
    setState(() {
      _latestSensor = arSensor;
      _sensorError = null;
    });
  }

  void _onSensorError(Object error) {
    if (!mounted) return;
    setState(() {
      _sensorError = error is ArSensorException
          ? error
          : ArSensorException(ArSensorErrorType.unknown, cause: error);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The view's own size, not the screen's: the projection must match the
    // camera preview behind it, which fills the same area.
    return LayoutBuilder(builder: (context, constraints) {
      final screen = MediaQuery.sizeOf(context);
      final width =
          constraints.hasBoundedWidth ? constraints.maxWidth : screen.width;
      final height =
          constraints.hasBoundedHeight ? constraints.maxHeight : screen.height;
      return _buildOverlay(context, width, height);
    });
  }

  Widget _buildOverlay(BuildContext context, double width, double height) {
    final arSensor = _latestSensor;
    if (arSensor == null || arSensor.location == null) {
      final error = _sensorError;
      if (error != null) {
        return widget.sensorErrorBuilder?.call(context, error) ??
            _defaultSensorError(error);
      }
      return loading();
    }

    final deviceLocation = arSensor.location!;
    final layout = _layoutEngine.layout(
      annotations: widget.annotations,
      arSensor: arSensor,
      deviceLocation: deviceLocation,
      width: width,
      height: height,
      config: AnnotationLayoutConfig(
        annotationWidth: widget.annotationWidth,
        annotationHeight: widget.annotationHeight,
        maxVisibleDistance: widget.maxVisibleDistance,
        paddingOverlap: widget.paddingOverlap,
        yOffsetOverlap: widget.yOffsetOverlap,
        cameraFieldOfView: widget.cameraFieldOfView ??
            _deviceCameraFieldOfView ??
            AnnotationLayoutConfig.defaultCameraFieldOfView,
        previewAspectRatio: widget.previewAspectRatio ??
            AnnotationLayoutConfig.defaultPreviewAspectRatio,
        useAltitude: widget.useAltitude,
        hideWithinLocationAccuracy: widget.hideWithinLocationAccuracy,
        maxRows: widget.maxRows,
        scaleWithDistance: widget.scaleWithDistance,
        minScale: widget.minScale,
      ),
      previousRows: _rows,
      geoCache: _geoCache,
    );
    _rows = layout.rows;
    final annotations = layout.annotations;
    return Stack(
      children: [
        if (kDebugMode && widget.showDebugInfoSensor)
          Positioned(
            bottom: 0,
            child: _debugInfo(context, arSensor, width),
          ),
        Stack(
          children: annotations
              .map(
                (e) {
                  return Positioned(
                    key: ValueKey(e.uid),
                    left: e.arPosition.dx,
                    top: e.arPosition.dy,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: e.arPositionOffset.dy),
                      duration: widget.rowAnimationDuration,
                      curve: Curves.easeOut,
                      builder: (context, dy, child) => Transform.translate(
                        offset: Offset(0, dy),
                        child: child,
                      ),
                      child: Transform.scale(
                        scale: e.arScale,
                        child: SizedBox(
                          width: widget.annotationWidth,
                          height: widget.annotationHeight,
                          child:
                              _annotationView(context, e, layout.groups[e.uid]),
                        ),
                      ),
                    ),
                  );
                },
              )
              .toList()
              .reversed
              .toList(),
        ),
        if (widget.showRadar)
          _radarPosition(
              widget.radarPosition ?? RadarPosition.topLeft,
              arSensor.heading,
              widget.radarWidth != null ? (widget.radarWidth! * 2) : width,
              width)
      ],
    );
  }

  Widget _annotationView(BuildContext context, ArAnnotation annotation,
      List<ArAnnotation>? grouped) {
    final view = widget.annotationViewBuilder(context, annotation);
    if (grouped == null || grouped.isEmpty) return view;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: view),
        Positioned(
          top: -8,
          right: -8,
          child: widget.groupBadgeBuilder?.call(context, annotation, grouped) ??
              _defaultGroupBadge(context, grouped.length),
        ),
      ],
    );
  }

  Widget _defaultGroupBadge(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '+$count',
        style: theme.textTheme.labelSmall
            ?.copyWith(color: theme.colorScheme.onPrimary),
      ),
    );
  }

  Widget _radarPosition(
      RadarPosition position, double heading, double width, double viewWidth) {
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
    switch (position) {
      case RadarPosition.topCenter:
        return Positioned(
          top: 0,
          left: viewWidth / 2 - width / 4,
          child: radar,
        );
      case RadarPosition.topRight:
        return Positioned(
          top: 0,
          right: 0,
          child: radar,
        );
      case RadarPosition.bottomLeft:
        return Positioned(
          bottom: 0,
          left: 0,
          child: radar,
        );
      case RadarPosition.bottomCenter:
        return Positioned(
          bottom: 0,
          left: viewWidth / 2 - width / 4,
          child: radar,
        );
      case RadarPosition.bottomRight:
        return Positioned(
          bottom: 0,
          right: 0,
          child: radar,
        );
      default:
        return radar;
    }
  }

  Widget _debugInfo(BuildContext context, ArSensor? arSensor, double width) {
    return Container(
      color: Colors.white,
      width: width,
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

  Widget _defaultSensorError(ArSensorException error) {
    final String message;
    switch (error.type) {
      case ArSensorErrorType.permissionDenied:
        message = 'Location permission denied';
        break;
      case ArSensorErrorType.permissionPermanentlyDenied:
        message = 'Location permission denied, enable it in the settings';
        break;
      case ArSensorErrorType.locationServiceDisabled:
        message = 'Location services are disabled';
        break;
      case ArSensorErrorType.unknown:
        message = 'Location unavailable';
        break;
    }
    return Center(
      child: Text(message, textAlign: TextAlign.center),
    );
  }

  Widget loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  void _updatePosition(Position newPosition) {
    if (position == null) {
      widget.onLocationChange(newPosition);
      position = newPosition;
    } else {
      final distance = Geolocator.distanceBetween(
        position!.latitude,
        position!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      if (distance > widget.minDistanceReload) {
        widget.onLocationChange(newPosition);
        position = newPosition;
      }
    }
  }
}
