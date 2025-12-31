import 'package:ar_location_view/ar_location_view.dart';
import 'package:ar_location_view_example/annotation_view.dart';
import 'package:ar_location_view_example/annotations.dart';
import 'package:flutter/material.dart';
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
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: ArLocationWidget(
          annotations: annotations,
          showDebugInfoSensor: false,
          annotationWidth: 180,
          annotationHeight: 60,
          radarPosition: RadarPosition.bottomCenter,
          annotationViewBuilder: (context, annotation) {
            return AnnotationView(
              key: ValueKey(annotation.uid),
              annotation: annotation as Annotation,
            );
          },
          radarWidth: 160,
          scaleWithDistance: false,
          onLocationChange: _onLocationChange,
        ),
      ),
    );
  }

  void _onLocationChange(Position position) {
    if (_isLoading) return;

    _isLoading = true;

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;

      setState(() {
        annotations = fakeAnnotation(
          position: position,
          numberMaxPoi: 10,
        );
        _isLoading = false;
      });
    });
  }
}
