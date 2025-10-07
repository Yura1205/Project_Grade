import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔄 Permitir todas las orientaciones para detección automática
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 🔑 obtiene las cámaras disponibles
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
      title: 'SignLang AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Tema iOS moderno
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF007AFF), // iOS blue
        scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS system gray
        
        // Tipografía estilo iOS
        fontFamily: 'SF Pro Display', // iOS system font
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: Colors.black,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
            color: Colors.black,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.black,
          ),
          bodyLarge: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
            color: Colors.black,
          ),
          bodyMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
            color: Colors.black,
          ),
        ),
        
        // AppBar estilo iOS
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
            size: 22,
          ),
        ),
        
        // Colores del sistema iOS
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007AFF), // iOS blue
          secondary: Color(0xFF34C759), // iOS green
          error: Color(0xFFFF3B30), // iOS red
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF000000),
          onPrimary: Color(0xFFFFFFFF),
        ),
        
        // Elevaciones y sombras estilo iOS
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
      home: CameraPage(camera: camera),
    );
  }
}