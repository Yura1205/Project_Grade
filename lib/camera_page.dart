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
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;

  final _predictionService = PredictionService();
  String _realTimeText = '';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _predictionService.loadModel();

    _cameras = await availableCameras();
    if (_cameras.isEmpty) return;

    await _initCamera(_cameras[_selectedCameraIdx]);

    _plugin = HandLandmarkerPlugin.create(
      numHands: 2,
      minHandDetectionConfidence: 0.7,
      delegate: HandLandmarkerDelegate.GPU,
    );

    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    await _controller!.initialize();
    await _controller!.startImageStream(_processCameraImage);
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras.length;

    await _controller?.stopImageStream();
    await _controller?.dispose();

    await _initCamera(_cameras[_selectedCameraIdx]);
    if (mounted) setState(() {});
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

    while (row.length < 126) {
      row.add(0.0);
    }

    row.add(numHands.toDouble());
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
    if (!_isInitialized || _controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Cámara ocupando toda la pantalla automáticamente
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover, // Ajusta la cámara sin barras negras
              alignment: Alignment.center,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Texto de predicción
          Positioned(
            bottom: 120,
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

          // Botón para cambiar de cámara
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch),
            ),
          ),
        ],
      ),
    );
  }
}
