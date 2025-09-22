import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hand_detection/prediction_service.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

class CameraPage extends StatefulWidget {
  final CameraDescription camera;

  const CameraPage({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  String _realTimeText = '';
  String _currentWord = ''; // palabra en construcción
  DateTime _lastPredictionTime = DateTime.now();
  Duration _predictionDelay = Duration(seconds: 2);

  final PredictionService _predictionService = PredictionService();
  final FlutterTts _tts = FlutterTts();

  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    _cameras = await availableCameras();
    await _initializeCamera(_cameras![_currentCameraIndex]);
    await _initializeHandLandmarker();
    _predictionService.loadModel();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(cameraDescription, ResolutionPreset.medium);
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    _controller!.startImageStream((image) {
      if (_plugin != null && _predictionService.isLoaded) {
        _processCameraImage(image);
      }
    });
  }

  Future<void> _initializeHandLandmarker() async {
    _plugin = await HandLandmarkerPlugin.create();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    final hands =
        await _plugin!.detect(image, _controller!.description.sensorOrientation);

    if (hands.isNotEmpty && _predictionService.isLoaded) {
      final hand = hands.first; // usamos la primera mano detectada
      var landmarks = hand.landmarks.map((lm) => [lm.x, lm.y, lm.z]).toList();

      // Ajustar rotación según la cámara
      landmarks = _rotateLandmarks(
          landmarks, _controller!.description.sensorOrientation);

      // Normalizar igual que en Python
      final vector = _predictionService.normalizeLandmarks(landmarks);

      while (vector.length < 126) {
        vector.add(0.0);
      }

      final prediction =
          await _predictionService.predict(vector, hands.length);

      if (prediction != null &&
          prediction.label != "N/A" &&
          prediction.confidence > 0.8) {
        final now = DateTime.now();

        if (now.difference(_lastPredictionTime) > _predictionDelay) {
          _lastPredictionTime = now;

          // Agregar letra actual a la palabra
          _currentWord += prediction.label;

          // Leer solo la letra actual
          _speak(prediction.label);

          setState(() {
            _realTimeText = prediction.label;
          });
        }
      }
    }
  }

  List<List<double>> _rotateLandmarks(
      List<List<double>> landmarks, int rotationDegrees) {
    final rad = rotationDegrees * pi / 180;
    final cosA = cos(rad);
    final sinA = sin(rad);

    return landmarks.map((lm) {
      final x = lm[0];
      final y = lm[1];
      final z = lm[2];
      return [
        x * cosA - y * sinA,
        x * sinA + y * cosA,
        z
      ];
    }).toList();
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage("es-ES"); // cambia según idioma
    await _tts.setSpeechRate(0.7);
    await _tts.speak(text);
  }

  void _deleteLastLetter() {
    if (_currentWord.isNotEmpty) {
      setState(() {
        _currentWord = _currentWord.substring(0, _currentWord.length - 1);
      });
    }
  }

  void _resetWord() {
    setState(() {
      _currentWord = '';
    });
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.isEmpty) return;
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
    await _controller?.dispose();
    await _initializeCamera(_cameras![_currentCameraIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reconocimiento de señas"),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          // Vista previa de la cámara
          Expanded(
            flex: 2,
            child: CameraPreview(_controller!),
          ),

          // Texto actual reconocido
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Seña actual: $_realTimeText",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Palabra construida en una sola línea
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentWord,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Botones de acciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _deleteLastLetter,
                  icon: const Icon(Icons.backspace),
                  label: const Text("Borrar"),
                ),
                ElevatedButton.icon(
                  onPressed: _resetWord,
                  icon: const Icon(Icons.clear),
                  label: const Text("Reset"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
