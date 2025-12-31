import 'package:flutter/material.dart';

import 'annotations.dart';

/// Widget displaying an AR annotation with icon and distance.
///
/// Uses Dart 3 switch expressions for cleaner icon/color selection.
class AnnotationView extends StatelessWidget {
  const AnnotationView({
    super.key,
    required this.annotation,
  });

  final Annotation annotation;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: Colors.black.withAlpha(80),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
              child: _buildIcon(annotation.type),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    annotation.type.name,
                    maxLines: 1,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${annotation.distanceFromUser.toInt()} m',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the icon widget based on annotation type.
  ///
  /// Uses Dart 3 switch expression for concise mapping.
  Widget _buildIcon(AnnotationType type) {
    final (iconData, color) = switch (type) {
      AnnotationType.pharmacy => (Icons.local_pharmacy_outlined, Colors.red),
      AnnotationType.hotel => (Icons.hotel_outlined, Colors.green),
      AnnotationType.library => (Icons.library_add_outlined, Colors.blue),
    };

    return Icon(
      iconData,
      size: 40,
      color: color,
    );
  }
}
