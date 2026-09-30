import 'dart:math';
import 'dart:ui';

import 'package:geolocator/geolocator.dart';

import 'ar_annotation.dart';
import 'ar_extension.dart';
import 'ar_projection.dart';
import 'ar_sensor.dart';
import 'ar_status.dart';

/// Configuration for [AnnotationLayoutEngine.layout].
class AnnotationLayoutConfig {
  const AnnotationLayoutConfig({
    required this.annotationWidth,
    required this.annotationHeight,
    required this.maxVisibleDistance,
    required this.paddingOverlap,
    this.yOffsetOverlap,
    this.cameraFieldOfView = defaultCameraFieldOfView,
    this.previewAspectRatio = defaultPreviewAspectRatio,
    this.useAltitude = false,
    this.rowHysteresis = 24,
    this.hideWithinLocationAccuracy = false,
    this.maxRows,
    this.scaleWithDistance = false,
    this.minScale = defaultMinScale,
    this.horizontalSpacing = 4,
  });

  /// Scale of a label at [maxVisibleDistance] when [scaleWithDistance].
  static const defaultMinScale = 0.5;

  /// Used when the real camera field of view cannot be read from the
  /// device.
  static const defaultCameraFieldOfView = 58.0;

  /// Most phone camera sensors are 4:3.
  static const defaultPreviewAspectRatio = 4 / 3;

  final double annotationWidth;
  final double annotationHeight;
  final double maxVisibleDistance;
  final double paddingOverlap;
  final double? yOffsetOverlap;

  /// Field of view of the camera along its long side, in degrees.
  final double cameraFieldOfView;

  /// Aspect ratio (long side / short side) of the camera preview.
  final double previewAspectRatio;

  /// Place POIs above/below the horizon from the altitude difference with
  /// the user. Off by default: it requires POI altitudes in the same
  /// reference as the GPS altitude (and not left to 0), otherwise POIs end
  /// up far below the horizon wherever the user is at high altitude.
  final bool useAltitude;

  /// Extra horizontal clearance, in pixels, a label needs before moving
  /// back down to a lower row than the one it had in the previous layout.
  /// Prevents labels from flickering between rows while the device moves.
  final double rowHysteresis;

  /// Hide POIs closer than the user location's accuracy: their bearing is
  /// meaningless when the user could be on either side of them.
  final bool hideWithinLocationAccuracy;

  /// Maximum number of overlap rows a label can be stacked on (the natural
  /// position counting as the first one). Labels are also never stacked
  /// above the top of the screen. Annotations that do not fit are grouped
  /// into an overlapping visible one, see [AnnotationLayoutResult.groups].
  /// Null means limited by the screen height only.
  final int? maxRows;

  /// Shrink labels linearly with their distance, from 1 next to the user to
  /// [minScale] at [maxVisibleDistance].
  final bool scaleWithDistance;

  final double minScale;

  /// Minimum horizontal gap, in pixels, between two labels on the same row.
  final double horizontalSpacing;
}

/// Result of [AnnotationLayoutEngine.layout]: the annotations currently
/// visible, positioned on screen and de-collided, together with the
/// field-of-view status used to compute them.
class AnnotationLayoutResult {
  const AnnotationLayoutResult({
    required this.annotations,
    required this.status,
    this.rows = const {},
    this.groups = const {},
  });

  /// Visible annotations, sorted by distance, with [ArAnnotation.arPosition]
  /// and [ArAnnotation.arPositionOffset] populated. `arPosition` is the
  /// label's top-left corner in screen coordinates, the label being centered
  /// on the POI's projection.
  final List<ArAnnotation> annotations;

  final ArStatus status;

  /// Overlap row of each visible annotation, by [ArAnnotation.uid]. Pass it
  /// back as `previousRows` to the next [AnnotationLayoutEngine.layout] call
  /// to keep labels on stable rows across frames.
  final Map<String, int> rows;

  /// Annotations that did not fit on screen once stacked, by the
  /// [ArAnnotation.uid] of the visible annotation they are grouped into
  /// (the overlapping one whose label is horizontally closest). They are
  /// not part of [annotations] and have [ArAnnotation.isVisible] false.
  final Map<String, List<ArAnnotation>> groups;
}

/// Pure Dart geometry engine: turns raw sensor data and a list of
/// [ArAnnotation] into the subset that is visible, positioned and
/// de-collided on screen.
///
/// Has no dependency on Flutter widgets/[BuildContext]/[State], so it can be
/// unit tested directly with `package:test`, without a `WidgetTester`.
class AnnotationLayoutEngine {
  const AnnotationLayoutEngine();

  AnnotationLayoutResult layout({
    required List<ArAnnotation> annotations,
    required ArSensor arSensor,
    required Position deviceLocation,
    required double width,
    required double height,
    required AnnotationLayoutConfig config,
    Map<String, int> previousRows = const {},
    AnnotationGeoCache? geoCache,
  }) {
    geoCache?.prepare(deviceLocation, annotations.length);
    final projection = ArProjection(
      width: width,
      height: height,
      cameraFieldOfView: config.cameraFieldOfView,
      previewAspectRatio: config.previewAspectRatio,
    );
    final rotation = arSensor.rotationMatrix ??
        ArRotation.fromHeadingPitch(arSensor.heading, arSensor.pitch);
    final status = _status(projection, arSensor, deviceLocation);

    final visible = <ArAnnotation>[];
    for (final annotation in annotations) {
      if (geoCache == null || !geoCache.restore(annotation)) {
        _locate(annotation, deviceLocation);
        geoCache?.store(annotation);
      }
      annotation.arScale = _scale(annotation, config);
      annotation.isVisible =
          annotation.distanceFromUser < config.maxVisibleDistance &&
              !(config.hideWithinLocationAccuracy &&
                  annotation.distanceFromUser < deviceLocation.accuracy) &&
              _place(annotation, deviceLocation.altitude, rotation, projection,
                  config);
      if (annotation.isVisible) visible.add(annotation);
    }

    final overlap = _transformAnnotation(visible, config, previousRows);
    visible.removeWhere((annotation) => !annotation.isVisible);

    return AnnotationLayoutResult(
      annotations: visible,
      status: status,
      rows: overlap.rows,
      groups: overlap.groups,
    );
  }

  ArStatus _status(
      ArProjection projection, ArSensor arSensor, Position deviceLocation) {
    final hFov = projection.horizontalFieldOfView;
    final vFov = projection.verticalFieldOfView;
    return ArStatus()
      ..hFov = hFov
      ..vFov = vFov
      ..hPixelPerDegree = hFov > 0 ? (projection.width / hFov) : 0
      ..vPixelPerDegree = vFov > 0 ? (projection.height / vFov) : 0
      ..heading = arSensor.heading
      ..pitch = arSensor.pitch
      ..userLocation = deviceLocation;
  }

  void _locate(ArAnnotation annotation, Position deviceLocation) {
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
        annotationLocation.longitude);
  }

  double _scale(ArAnnotation annotation, AnnotationLayoutConfig config) {
    if (!config.scaleWithDistance || config.maxVisibleDistance <= 0) return 1;
    final t = (annotation.distanceFromUser / config.maxVisibleDistance)
        .clamp(0.0, 1.0);
    return 1 - t * (1 - config.minScale);
  }

  /// Projects [annotation] on screen and sets its [ArAnnotation.arPosition].
  /// Returns false when it is behind the camera or when its label would not
  /// intersect the screen at all.
  bool _place(
      ArAnnotation annotation,
      double userAltitude,
      List<double> rotation,
      ArProjection projection,
      AnnotationLayoutConfig config) {
    final elevation = config.useAltitude
        ? atan2(annotation.position.altitude - userAltitude,
                max(annotation.distanceFromUser, 1))
            .toDegrees
        : 0.0;
    final point = projection.project(
        rotation, ArProjection.direction(annotation.azimuth, elevation));
    if (point == null) return false;

    final left = point.dx - config.annotationWidth / 2;
    final top = point.dy - config.annotationHeight / 2;
    annotation.arPosition = Offset(left, top);
    return left < projection.width &&
        left + config.annotationWidth > 0 &&
        top < projection.height &&
        top + config.annotationHeight > 0;
  }

  /// Resolves horizontal overlaps between annotation labels by stacking
  /// colliding ones onto extra vertical "rows".
  ///
  /// Annotations are processed in distance order (closest first, so closer
  /// POIs keep their natural, unshifted position); each one is placed on the
  /// first row whose already-placed intervals it doesn't overlap. Checking a
  /// row is a binary search against its sorted, non-overlapping intervals
  /// ([_Row.overlaps]), but inserting into it shifts a list, and a label
  /// may have to try every row: the worst case is O(n²) (every label at the
  /// same position), which is fine for the few dozen labels a screen holds.
  ///
  /// Overlaps use each label's displayed extent: its width times
  /// [ArAnnotation.arScale] around its center, plus
  /// [AnnotationLayoutConfig.horizontalSpacing].
  ///
  /// To stay stable across frames, an annotation keeps its row from
  /// [previousRows] while it still fits there, and only moves down to a
  /// lower row once it fits there with [AnnotationLayoutConfig.rowHysteresis]
  /// of clearance.
  ///
  /// Rows are bounded by [AnnotationLayoutConfig.maxRows] and by the top of
  /// the screen. An annotation fitting in none of its allowed rows is
  /// grouped into the placed annotation it overlaps whose center is the
  /// closest, and marked as not visible. Since annotations are processed
  /// closest first, the farthest ones are the ones grouped.
  _OverlapResult _transformAnnotation(List<ArAnnotation> annotations,
      AnnotationLayoutConfig config, Map<String, int> previousRows) {
    annotations
        .sort((a, b) => a.distanceFromUser.compareTo(b.distanceFromUser));

    final step = (config.yOffsetOverlap ?? config.annotationHeight) +
        config.paddingOverlap;
    final rows = <_Row>[];
    final assigned = <String, int>{};
    final groups = <String, List<ArAnnotation>>{};
    final placed = <_Placed>[];

    for (final annotation in annotations) {
      final halfWidth = config.annotationWidth * annotation.arScale / 2 +
          config.horizontalSpacing / 2;
      final center = annotation.arPosition.dx + config.annotationWidth / 2;
      final start = center - halfWidth;
      final end = center + halfWidth;
      final rowIndex = _chooseRow(
        rows,
        start,
        end,
        previousRows[annotation.uid],
        config.rowHysteresis,
        _maxRow(annotation, step, config.maxRows),
      );

      if (rowIndex == null) {
        final host = _closestOverlapping(placed, start, end);
        if (host != null) {
          annotation.isVisible = false;
          (groups[host.uid] ??= []).add(annotation);
          continue;
        }
      }
      final row = rowIndex ?? 0;

      while (rows.length <= row) {
        rows.add(_Row());
      }
      annotation.arPositionOffset = Offset(0, -row * step);
      rows[row].insert(start, end);
      assigned[annotation.uid] = row;
      placed.add(_Placed(annotation, start, end));
    }
    return _OverlapResult(assigned, groups);
  }

  /// Highest row [annotation] may be stacked on: within
  /// [maxRows] and without its label going above the top of the screen.
  int _maxRow(ArAnnotation annotation, double step, int? maxRows) {
    var maxRow = step > 0 ? (annotation.arPosition.dy / step).floor() : 0;
    if (maxRows != null) maxRow = min(maxRow, maxRows - 1);
    // The natural position is always allowed, even partially off screen.
    return max(maxRow, 0);
  }

  /// Returns null when no row up to [maxRow] can hold the label.
  int? _chooseRow(List<_Row> rows, double start, double end, int? previousRow,
      double hysteresis, int maxRow) {
    bool fits(int index, double margin) =>
        index >= rows.length ||
        !rows[index].overlaps(start - margin, end + margin);

    if (previousRow != null && previousRow <= maxRow) {
      for (var i = 0; i < previousRow; i++) {
        if (fits(i, hysteresis)) return i;
      }
      if (fits(previousRow, 0)) return previousRow;
    }
    for (var i = 0; i <= maxRow; i++) {
      if (fits(i, 0)) return i;
    }
    return null;
  }

  ArAnnotation? _closestOverlapping(
      List<_Placed> placed, double start, double end) {
    final center = (start + end) / 2;
    ArAnnotation? closest;
    var closestDistance = double.infinity;
    for (final candidate in placed) {
      if (candidate.start > end || candidate.end < start) continue;
      final distance = ((candidate.start + candidate.end) / 2 - center).abs();
      if (distance < closestDistance) {
        closest = candidate.annotation;
        closestDistance = distance;
      }
    }
    return closest;
  }
}

class _Placed {
  const _Placed(this.annotation, this.start, this.end);

  final ArAnnotation annotation;
  final double start;
  final double end;
}

/// Caches each annotation's bearing and distance from the user, which only
/// change when the user or the annotation moves, instead of recomputing them
/// for every annotation on every frame. Keep one instance per view and pass
/// it to each [AnnotationLayoutEngine.layout] call.
class AnnotationGeoCache {
  final Map<String, _GeoEntry> _entries = {};
  double? _latitude;
  double? _longitude;

  /// Invalidates everything when the user moved, and drops entries of
  /// annotations that are no longer laid out.
  void prepare(Position deviceLocation, int annotationCount) {
    if (deviceLocation.latitude != _latitude ||
        deviceLocation.longitude != _longitude) {
      _entries.clear();
      _latitude = deviceLocation.latitude;
      _longitude = deviceLocation.longitude;
    } else if (_entries.length > 2 * annotationCount + 16) {
      _entries.clear();
    }
  }

  /// Restores [annotation]'s azimuth and distance; false when unknown or
  /// stale (the annotation moved).
  bool restore(ArAnnotation annotation) {
    final entry = _entries[annotation.uid];
    if (entry == null ||
        entry.latitude != annotation.position.latitude ||
        entry.longitude != annotation.position.longitude) {
      return false;
    }
    annotation.azimuth = entry.azimuth;
    annotation.distanceFromUser = entry.distance;
    return true;
  }

  void store(ArAnnotation annotation) {
    _entries[annotation.uid] = _GeoEntry(
      annotation.position.latitude,
      annotation.position.longitude,
      annotation.azimuth,
      annotation.distanceFromUser,
    );
  }

  void clear() => _entries.clear();
}

class _GeoEntry {
  const _GeoEntry(this.latitude, this.longitude, this.azimuth, this.distance);

  final double latitude;
  final double longitude;
  final double azimuth;
  final double distance;
}

class _OverlapResult {
  const _OverlapResult(this.rows, this.groups);

  final Map<String, int> rows;
  final Map<String, List<ArAnnotation>> groups;
}

/// A row of horizontally non-overlapping `[start, end]` intervals, kept
/// sorted by `start`. Because the intervals in a row never overlap each
/// other, only the immediate neighbours of the insertion point can possibly
/// overlap a new interval, so [overlaps] only needs a binary search plus two
/// comparisons rather than scanning every interval already in the row.
class _Row {
  final List<double> _starts = [];
  final List<double> _ends = [];

  bool overlaps(double start, double end) {
    final index = _lowerBound(start);
    if (index > 0 && _ends[index - 1] >= start) return true;
    if (index < _starts.length && _starts[index] <= end) return true;
    return false;
  }

  void insert(double start, double end) {
    final index = _lowerBound(start);
    _starts.insert(index, start);
    _ends.insert(index, end);
  }

  int _lowerBound(double start) {
    var lo = 0;
    var hi = _starts.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_starts[mid] < start) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
