import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ar_compass.dart';

/// An overlay widget that displays a figure-8 animation to guide
/// the user through compass calibration.
///
/// This widget should be shown when [CompassCalibrationStatus.needsCalibration]
/// returns true.
class CompassCalibrationOverlay extends StatefulWidget {
  const CompassCalibrationOverlay({
    super.key,
    this.onDismiss,
    this.backgroundColor = Colors.black87,
    this.phoneColor = Colors.white,
    this.pathColor = Colors.blue,
    this.title = 'Calibration requise',
    this.subtitle = 'Faites un mouvement en forme de 8 avec votre téléphone',
    this.dismissButtonText = 'Fermer',
  });

  /// Called when the user dismisses the overlay.
  final VoidCallback? onDismiss;

  /// Background color of the overlay.
  final Color backgroundColor;

  /// Color of the animated phone icon.
  final Color phoneColor;

  /// Color of the figure-8 path.
  final Color pathColor;

  /// Title text displayed above the animation.
  final String title;

  /// Subtitle text displayed below the title.
  final String subtitle;

  /// Text for the dismiss button.
  final String dismissButtonText;

  @override
  State<CompassCalibrationOverlay> createState() =>
      _CompassCalibrationOverlayState();
}

class _CompassCalibrationOverlayState extends State<CompassCalibrationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: widget.backgroundColor,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: widget.phoneColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              widget.subtitle,
              style: TextStyle(
                color: widget.phoneColor.withValues(alpha: 0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _Figure8Painter(
                      progress: _controller.value,
                      phoneColor: widget.phoneColor,
                      pathColor: widget.pathColor,
                    ),
                    size: const Size(250, 250),
                  );
                },
              ),
            ),
            const SizedBox(height: 48),
            if (widget.onDismiss != null)
              TextButton(
                onPressed: widget.onDismiss,
                child: Text(
                  widget.dismissButtonText,
                  style: TextStyle(
                    color: widget.phoneColor,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that draws a figure-8 path and an animated phone icon.
class _Figure8Painter extends CustomPainter {
  _Figure8Painter({
    required this.progress,
    required this.phoneColor,
    required this.pathColor,
  });

  final double progress;
  final Color phoneColor;
  final Color pathColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final loopRadius = size.width * 0.22;

    // Draw the figure-8 path
    final pathPaint = Paint()
      ..color = pathColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    const steps = 100;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = _getFigure8Point(t, center, loopRadius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, pathPaint);

    // Draw the animated phone
    final phonePosition = _getFigure8Point(progress, center, loopRadius);
    final phoneAngle = _getFigure8Angle(progress);

    canvas.save();
    canvas.translate(phonePosition.dx, phonePosition.dy);
    canvas.rotate(phoneAngle);

    // Phone body
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 30, height: 50),
      const Radius.circular(6),
    );

    final phonePaint = Paint()
      ..color = phoneColor
      ..style = PaintingStyle.fill;

    final phoneBorderPaint = Paint()
      ..color = pathColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(phoneRect, phonePaint);
    canvas.drawRRect(phoneRect, phoneBorderPaint);

    // Screen
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -3), width: 22, height: 36),
      const Radius.circular(2),
    );
    final screenPaint = Paint()..color = pathColor.withValues(alpha: 0.5);
    canvas.drawRRect(screenRect, screenPaint);

    // Home button / notch
    final buttonPaint = Paint()..color = pathColor.withValues(alpha: 0.5);
    canvas.drawCircle(const Offset(0, 18), 4, buttonPaint);

    canvas.restore();
  }

  /// Calculates a point on the figure-8 (lemniscate) path.
  Offset _getFigure8Point(double t, Offset center, double radius) {
    // Parametric equation for figure-8 (lemniscate of Bernoulli variation)
    final angle = t * 2 * math.pi;
    final x = radius * 1.5 * math.sin(angle);
    final y = radius * math.sin(2 * angle);
    return Offset(center.dx + x, center.dy + y);
  }

  /// Calculates the rotation angle for the phone at a given position.
  double _getFigure8Angle(double t) {
    // Derivative of the figure-8 path to get tangent angle
    final angle = t * 2 * math.pi;
    final dx = 1.5 * math.cos(angle);
    final dy = 2 * math.cos(2 * angle);
    return math.atan2(dy, dx) + math.pi / 2;
  }

  @override
  bool shouldRepaint(_Figure8Painter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// A convenient dialog to show the calibration overlay.
///
/// Usage:
/// ```dart
/// if (compassEvent.calibrationStatus?.needsCalibration ?? false) {
///   showCompassCalibrationDialog(context);
/// }
/// ```
Future<void> showCompassCalibrationDialog(
  BuildContext context, {
  Color? backgroundColor,
  Color? phoneColor,
  Color? pathColor,
  String? title,
  String? subtitle,
  String? dismissButtonText,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => CompassCalibrationOverlay(
      backgroundColor: backgroundColor ?? Colors.black87,
      phoneColor: phoneColor ?? Colors.white,
      pathColor: pathColor ?? Theme.of(context).primaryColor,
      title: title ?? 'Calibration requise',
      subtitle:
          subtitle ?? 'Faites un mouvement en forme de 8 avec votre téléphone',
      dismissButtonText: dismissButtonText ?? 'Fermer',
      onDismiss: () => Navigator.of(context).pop(),
    ),
  );
}
