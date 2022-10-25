import 'dart:math';

import 'package:flutter/material.dart';

import 'ar_location_view.dart';

enum RadarPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class RadarPainter extends CustomPainter {
  const RadarPainter({
    required this.maxDistance,
    required this.arAnnotations,
    required this.heading,
    required this.markerColor,
    required this.background,
  });

  final angle = pi / 7;

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
    final pointA =
        Offset(radius * (1 - sin(angleView)), radius * (1 - cos(angleView)));
    final pointB =
        Offset(radius * (1 - sin(angleView1)), radius * (1 - cos(angleView1)));
    path.moveTo(pointA.dx, pointA.dy);
    path.lineTo(radius, radius);
    path.lineTo(pointB.dx, pointB.dy);
    path.arcToPoint(pointA, radius: Radius.circular(radius));

    final Paint paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blueAccent.withAlpha(168),
          Colors.blueAccent.withAlpha(20),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(radius, radius),
        radius: radius,
      ))
      ..style = PaintingStyle.fill;
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
