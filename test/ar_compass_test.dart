import 'package:ar_location_view/ar_location_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompassEvent.fromList', () {
    test('handles a null payload', () {
      final event = CompassEvent.fromList(null);

      expect(event.heading, isNull);
      expect(event.headingForCameraMode, isNull);
      expect(event.accuracy, isNull);
      expect(event.rotationMatrix, isNull);
    });

    test('reads a heading-only payload', () {
      final event = CompassEvent.fromList([10, 20, 15]);

      expect(event.heading, 10);
      expect(event.headingForCameraMode, 20);
      expect(event.accuracy, 15);
      expect(event.rotationMatrix, isNull);
    });

    test('maps an accuracy of -1 to unknown', () {
      expect(CompassEvent.fromList([10, 20, -1]).accuracy, isNull);
    });

    test('reads the rotation matrix of a full payload', () {
      final matrix = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
      final event = CompassEvent.fromList([10, 20, 15, ...matrix]);

      expect(event.rotationMatrix, matrix);
      expect(() => event.rotationMatrix!.add(0), throwsUnsupportedError);
    });
  });
}
