import 'package:vector_math/vector_math_64.dart';

extension NumExt on num {
  double get toDegrees => this * radians2Degrees;

  double get toRadians => this * degrees2Radians;
}
