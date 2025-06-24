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
    this.borderColor = Colors.grey, // Border color
    this.borderWidth = 2.0, // Border width
  });

  final angle = pi / 7;

  final Color markerColor;
  final Color background;
  final double maxDistance;
  final List<ArAnnotation> arAnnotations;
  final double heading;
  final Color borderColor; // New field for border color
  final double borderWidth; // New field for border width

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final angleView = -(angle + heading.toRadians);
    final angleView1 = -(-angle + heading.toRadians);
    final center = Offset(radius, radius);

    // Radar background
    final Paint backgroundPaint = Paint()
      ..color = background.withOpacity(0.6);
    canvas.drawCircle(center, radius, backgroundPaint);

    // Radar field of view
    final Path path = Path();
    final pointA =
    Offset(radius * (1 - sin(angleView)), radius * (1 - cos(angleView)));
    final pointB =
    Offset(radius * (1 - sin(angleView1)), radius * (1 - cos(angleView1)));
    path.moveTo(pointA.dx, pointA.dy);
    path.lineTo(radius, radius);
    path.lineTo(pointB.dx, pointB.dy);
    path.arcToPoint(pointA, radius: Radius.circular(radius));

    // Gradient effect
    final Paint gradientPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.grey.withAlpha(168),
          Colors.grey.withAlpha(20),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(radius, radius),
        radius: radius,
      ))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, gradientPaint);

    // Radar border
    final Paint borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw markers
    drawMarker(canvas, arAnnotations, radius);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  void drawMarker(Canvas canvas, List<ArAnnotation> annotations,
      double radius) {
    // Define the clipping region as a circle
    final Path clipPath = Path()
      ..addOval(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius));
    canvas.save(); // Save the current canvas state
    canvas.clipPath(clipPath); // Apply the clipping path

    // Draw the markers
    for (final annotation in annotations) {
      final Paint paint = Paint()
        ..color = markerColor;
      final distanceInRadar = annotation.distanceFromUser / maxDistance *
          radius;

      // Calculate the position of the marker
      final alpha = pi - annotation.azimuth.toRadians;
      final dx = (distanceInRadar) * sin(alpha);
      final dy = (distanceInRadar) * cos(alpha);
      final center = Offset(dx + radius, dy + radius);

      // Draw the marker
      canvas.drawCircle(center, 3, paint);
    }

    canvas.restore(); // Restore the canvas to remove the clipping
  }

}
