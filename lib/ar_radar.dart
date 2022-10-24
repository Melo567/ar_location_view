import 'package:flutter/material.dart';

class RadarPainter extends CustomPainter {

  RadarPainter();

  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(20, 20), 20, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
