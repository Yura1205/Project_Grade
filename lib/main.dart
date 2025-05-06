import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reconocimiento de señas',
      home: const CameraPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Interpreter _interpreter;
  List<String> _labels = [];

  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller.initialize();
    setState(() {
      _isCameraInitialized = true;
    });
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('sign_language_model_quant.tflite');
    final labelData = await rootBundle.loadString('assets/labels.json');
    final Map<String, dynamic> labelsMap = json.decode(labelData);
    _labels = List.filled(labelsMap.length, '');
    labelsMap.forEach((key, value) {
      _labels[value] = key;
    });
  }

  Future<void> _captureAndClassify() async {
    try {
      final file = await _controller.takePicture();
      final prediction = await _predictImage(File(file.path));
      _showPopup(prediction);
    } catch (e) {
      print("Error capturando y clasificando: $e");
    }
  }

  Future<String> _predictImage(File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  img.Image? image = img.decodeImage(bytes);
  if (image == null) return 'Imagen no válida';

  // Convertir a escala de grises y redimensionar
  image = img.grayscale(image);
  image = img.copyResize(image, width: 224, height: 224);

  // Si tu cámara guarda imágenes giradas, puedes rotarla:
  // image = img.copyRotate(image, 90);

  // Preparar input con forma [1, 224, 224, 1]
  var input = List.generate(
    1,
    (_) => List.generate(
      224,
      (y) => List.generate(
        224,
        (x) {
          final pixel = image!.getPixel(x, y);
          final gray = img.getLuminance(pixel) / 255.0;
          return gray;
        },
      ),
    ),
  );

  // Preparar output
  var output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

  // Ejecutar inferencia
  _interpreter.run(input, output);

  // Obtener índice con la mayor probabilidad
  int maxIndex = output[0]
      .indexWhere((e) => e == output[0].reduce((a, b) => a > b ? a : b));

  return _labels[maxIndex];
}


  void _showPopup(String prediction) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Resultado"),
        content: Text("Seña detectada: $prediction"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? CameraPreview(_controller)
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.pan_tool),
        onPressed: () {
          Timer(const Duration(seconds: 5), _captureAndClassify);
        },
      ),
    );
  }
}
