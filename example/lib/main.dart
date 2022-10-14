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
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ArLocationWidget(
            annotations: dataFromJson(data).data,
            annotationViewBuilder: (context, annotation) {
              return ImmoAnnotationView(
                  onClick: () {}, annotation: annotation as ImmoAnnotation);
            },
            onLocationChange: (Position position) {}),
      ),
    );
  }
}
