import 'package:ar_location_view_example/annotation_view.dart';
import 'package:ar_location_view_example/annotations.dart';
import 'package:flutter/material.dart';
import 'package:ar_location_view/ar_location_view.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Annotation> annotations = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ArLocationWidget(
          annotations: annotations,
          showDebugInfoSensor: false,
          annotationViewBuilder: (context, annotation) {
            return AnnotationView(
              key: ValueKey(annotation.uid),
              annotation: annotation as Annotation,
            );
          },
          onLocationChange: (Position position) {
            Future.delayed(const Duration(seconds: 5), () {
              annotations =
                  fakeAnnotation(position: position, numberMaxPoi: 50);
              setState(() {});
            });
          },
        ),
      ),
    );
  }
}
