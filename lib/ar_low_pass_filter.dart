/// Recursive exponential moving average (first-order low-pass filter).
///
/// Unlike a weighted sum over a truncated history, the output has unit gain:
/// a constant input converges to that same value, and the very first sample
/// is returned as-is instead of starting from 0.
class LowPassFilter {
  LowPassFilter({required this.alpha})
      : assert(alpha > 0 && alpha <= 1, 'alpha must be in (0, 1]');

  /// Weight given to each new sample. Smaller means smoother but laggier.
  final double alpha;

  double? _value;

  double? get value => _value;

  double add(double sample) {
    final previous = _value;
    return _value =
        previous == null ? sample : previous + alpha * (sample - previous);
  }

  void reset() => _value = null;
}
