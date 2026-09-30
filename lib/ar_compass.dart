import 'package:flutter/services.dart';

class CompassEvent {
  // The heading, in degrees, of the device around its Z
  // axis, or where the top of the device is pointing.
  final double? heading;

  // The heading, in degrees, of the device around its X axis, or
  // where the back of the device is pointing.
  final double? headingForCameraMode;

  // The deviation error, in degrees, plus or minus from the heading.
  // NOTE: for iOS this is computed by the platform and is reliable. For
  // Android several values are hard-coded, and the true error could be more
  // or less than the value here.
  final double? accuracy;

  /// Device attitude, see [ArSensor.rotationMatrix]. Null when the platform
  /// cannot provide it (e.g. no motion sensors on a simulator).
  final List<double>? rotationMatrix;

  CompassEvent.fromList(List<double>? data)
      : heading = data?[0],
        headingForCameraMode = data?[1],
        accuracy = (data == null) || (data[2] == -1) ? null : data[2],
        rotationMatrix = data != null && data.length >= 12
            ? List<double>.unmodifiable(data.sublist(3, 12))
            : null;

  @override
  String toString() {
    return 'heading: $heading\nheadingForCameraMode: $headingForCameraMode\naccuracy: $accuracy';
  }
}

class ArCompass {
  static final ArCompass _instance = ArCompass._();

  factory ArCompass() {
    return _instance;
  }

  ArCompass._();

  static const EventChannel _compassChannel =
      EventChannel('pie/ar_view_location');
  static Stream<CompassEvent>? _stream;

  /// Provides a [Stream] of compass events that can be listened to.
  static Stream<CompassEvent>? get events {
    _stream ??= _compassChannel
        .receiveBroadcastStream()
        .map((dynamic data) => CompassEvent.fromList(data?.cast<double>()));
    return _stream;
  }
}
