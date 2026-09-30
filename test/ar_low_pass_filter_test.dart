import 'package:ar_location_view/ar_low_pass_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the first sample unchanged', () {
    final filter = LowPassFilter(alpha: 0.009);
    expect(filter.add(30), 30);
  });

  test('has unit gain: a constant input stays at that value', () {
    final filter = LowPassFilter(alpha: 0.009);
    late double output;
    for (var i = 0; i < 500; i++) {
      output = filter.add(30);
    }
    expect(output, closeTo(30, 1e-9));
  });

  test('converges towards a new value after a step', () {
    final filter = LowPassFilter(alpha: 0.1)..add(0);
    late double output;
    for (var i = 0; i < 200; i++) {
      output = filter.add(10);
    }
    expect(output, closeTo(10, 1e-6));
  });
}
