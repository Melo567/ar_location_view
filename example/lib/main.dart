import 'package:flutter/material.dart';
import 'package:ar_location_view/ar_location_view.dart';

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
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: StreamBuilder(
            stream: ArCompass.events,
            builder: (context, data) {
              if (data.hasData) {
                return Text('Compass: ${data.data?.heading}');
              }
              return Text('No data');
            }),
      ),
    );
  }
}
