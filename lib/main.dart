import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // � Forzar orientación horizontal
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // �🔑 obtiene las cámaras disponibles
  final cameras = await availableCameras();

  // Por ejemplo, usamos la cámara trasera
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lengua de Señas',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: CameraPage(camera: camera), // 👈 pasamos la cámara
    );
  }
}
