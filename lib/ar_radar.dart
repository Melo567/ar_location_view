import 'dart:math';

import 'package:flutter/material.dart';

import 'ar_location_view.dart';

class RadarPainter extends CustomPainter {
  const RadarPainter({
    required this.maxDistance,
    required this.arAnnotations,
    required this.heading,
    this.markerColor = Colors.red,
    this.background = Colors.grey,
  });

  final angle = pi / 6;

  final Color markerColor;
  final Color background;
  final double maxDistance;
  final List<ArAnnotation> arAnnotations;
  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final angleView = -(angle + heading.toRadians);
    final angleView1 = -(-angle + heading.toRadians);
    final center = Offset(radius, radius);
    final Paint paint = Paint()..color = background.withAlpha(100);
    final Path path = Path();
    path.moveTo(radius * (1 - sin(angleView)), radius * (1 - cos(angleView)));
    path.lineTo(radius, radius);
    path.lineTo(radius * (1 - sin(angleView1)), radius * (1 - cos(angleView1)));
    final Paint paint2 = Paint()
      ..color = Colors.green.withAlpha(200)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    canvas.drawPath(path, paint2);
    drawMarker(canvas, arAnnotations, radius);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void drawMarker(
      Canvas canvas, List<ArAnnotation> annotations, double radius) {
    for (final annotation in annotations) {
      final Paint paint = Paint()..color = markerColor;
      final distanceInRadar =
          annotation.distanceFromUser / maxDistance * radius;
      final alpha = pi - annotation.azimuth.toRadians;
      final dx = (distanceInRadar) * sin(alpha);
      final dy = (distanceInRadar) * cos(alpha);
      final center = Offset(dx + radius, dy + radius);
      canvas.drawCircle(center, 3, paint);
    }
  }
}
