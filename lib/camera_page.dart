import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'prediction_service.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  HandLandmarkerPlugin? _plugin;
  bool _isInitialized = false;
  bool _isDetecting = false;

  final _predictionService = PredictionService();
  String _realTimeText = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // inicializar modelo
    await _predictionService.loadModel();

    // inicializar cámara
    final cameras = await availableCameras();
    final camera = cameras.first;

    _controller = CameraController(camera, ResolutionPreset.medium, enableAudio: false);

    // inicializar plugin
    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.7,
      delegate: HandLandmarkerDelegate.GPU,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || !_isInitialized || _plugin == null) return;
    _isDetecting = true;

    try {
      final hands = _plugin!.detect(image, _controller!.description.sensorOrientation);

      if (hands.isNotEmpty && _predictionService.isLoaded) {
        final vector = _buildInputVector(hands);
        final prediction = await _predictionService.predict(vector);

        setState(() {
          _realTimeText = prediction;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isDetecting = false;
    }
  }

  List<double> _buildInputVector(List<Hand> hands) {
    List<double> row = [];

    int numHands = hands.length;

    for (var hand in hands) {
      for (var lm in hand.landmarks) {
        row.add(lm.x);
        row.add(lm.y);
        row.add(lm.z);
      }
    }

    // padding si falta mano
    while (row.length < 126) {
      row.add(0.0);
    }

    row.add(numHands.toDouble()); // número de manos
    return row;
  }

  @override
  void dispose() {
    _controller?.dispose();
    _plugin?.dispose();
    _predictionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              color: Colors.black54,
              child: Text(
                _realTimeText,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
