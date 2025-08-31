import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'history_page.dart'; // Asegúrate de tener este archivo creado
import 'package:flutter_mediapipe/flutter_mediapipe.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
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
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: CameraPage(camera: camera),
    );
  }
}

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({super.key, required this.camera});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late Interpreter _interpreter;
  late Map<String, String> _labels;
  bool _isProcessing = false;
  bool _modelLoaded = false;
  bool _isRealTimeEnabled = false;
  final List<Map<String, String>> _history = [];

  String _realTimeText = '';
  String _lastPrediction = ''; // 👉 Para comparar y evitar duplicados

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
          'assets/models/sign_language_model_quant.tflite');
      final jsonStr = await rootBundle.loadString('assets/labels.json');
      _labels = Map<String, String>.from(json.decode(jsonStr));

      setState(() {
        _modelLoaded = true;
      });

      if (mounted) {
        _startRealTimePrediction(); // 👉 Arrancar predicciones en tiempo real
      }
    } catch (e) {
      print("Error cargando modelo o etiquetas: $e");
    }
  }

  void _startRealTimePrediction() async {
    while (mounted && _isRealTimeEnabled) {
      await Future.delayed(const Duration(seconds: 2));
      if (_controller.value.isInitialized && !_isProcessing && _modelLoaded) {
        await _captureAndPredictInBackground();
      }
    }
  }

  Future<void> _captureAndPredictInBackground() async {
    _isProcessing = true;
    try {
      final file = await _controller.takePicture();
      final prediction = await _predictImage(File(file.path));

      if (prediction != _lastPrediction) {
        _lastPrediction = prediction;

        // Mostrar traducción en tiempo real
        setState(() {
          _realTimeText = prediction;
        });

        // Guardar imagen en historial
        final directory = await getApplicationDocumentsDirectory();
        final imagePath =
            '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
        await File(file.path).copy(imagePath);

        setState(() {
          _history.add({
            'image': imagePath,
            'label': prediction,
          });

          // 👉 Limitar historial a 20 elementos
          if (_history.length > 20) {
            _history.removeAt(0);
          }
        });
      }
    } catch (e) {
      print("Error en predicción en tiempo real: $e");
    } finally {
      _isProcessing = false;
    }
  }

  Future<String> _predictImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    final resized = img.copyResize(image!,
        width: 224, height: 224, interpolation: img.Interpolation.linear);
    final grayscale = img.grayscale(resized);

    final input = List.generate(1, (_) {
      return List.generate(224, (y) {
        return List.generate(224, (x) {
          return [grayscale.getPixel(x, y).r / 255.0];
        });
      });
    });

    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter.run(input, output);

    final predictedIndex = (output[0] as List<double>)
        .asMap()
        .entries
        .reduce((MapEntry<int, double> a, MapEntry<int, double> b) =>
            a.value > b.value ? a : b)
        .key;

    return _labels.containsKey(predictedIndex.toString())
        ? _labels[predictedIndex.toString()]!
        : 'Desconocido';
  }

  Future<void> _showPopup(String prediction, File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagePath =
        '${directory.path}/${DateTime.now().millisecondsSinceEpoch}.png';
    await imageFile.copy(imagePath);

    setState(() {
      _history.add({
        'image': imagePath,
        'label': prediction,
      });
    });

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text(
          "Resultado",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath), height: 200),
            const SizedBox(height: 12),
            Text(
              "Seña detectada: $prediction",
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          // Vista previa de cámara
          SizedBox.expand(
            child: CameraPreview(_controller),
          ),

          // AppBar y línea blanca
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Traductor de Lengua de Señas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ✅ Área de traducción en tiempo real
          Positioned(
            top: MediaQuery.of(context).size.height * 0.75,
            left: MediaQuery.of(context).size.width * 0.1,
            child: Column(
              children: [
                Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _realTimeText,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                // 👇 Botón ON/OFF
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isRealTimeEnabled ? Icons.stop : Icons.play_arrow,
                    ),
                    color: Colors.white,
                    iconSize: 30,
                    tooltip: _isRealTimeEnabled ? 'Detener' : 'Traducir',
                    onPressed: () {
                      setState(() {
                        _isRealTimeEnabled = !_isRealTimeEnabled;
                      });
                      if (_isRealTimeEnabled) {
                        _startRealTimePrediction();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Botón de historial
          Positioned(
            bottom: 30,
            right: 30,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: IconButton(
                icon: const Icon(Icons.history),
                color: Colors.white,
                iconSize: 24,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HistoryPage(history: _history),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
