import 'package:flutter/material.dart';
import 'camera_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lengua de Señas',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const CameraPage(),
    );
  }
}
