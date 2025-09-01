/*import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
  bool _isProcessing = false;
  int _cameraIndex = 0;
  String _prediction = '';

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
        cameras[_cameraIndex], ResolutionPreset.medium,
        enableAudio: false);
    await _controller.initialize();
    if (!mounted) return;
    setState(() {
      _isCameraInitialized = true;
    });
    _controller.startImageStream((CameraImage image) {
      if (_isProcessing) return;
      _isProcessing = true;
      Timer(const Duration(seconds: 2), () async {
        await _runModelOnFrame(image);
        _isProcessing = false;
      });
    });
  }

  Future<void> _loadModel() async {
    _interpreter = await Interpreter.fromAsset('sign_language_model.tflite');
    final labelData = await rootBundle.loadString('assets/labels.json');
    final Map<String, dynamic> labelsMap = json.decode(labelData);
    _labels = List.generate(labelsMap.length,
        (index) => labelsMap.entries.firstWhere((e) => e.value == index).key);
  }

  Future<void> _runModelOnFrame(CameraImage image) async {
    TensorImage input = await _convertYUV420ToImageTensor(image);
    var output = TensorBuffer.createFixedSize(
        <int>[1, _labels.length], TfLiteType.float32);
    _interpreter.run(input.buffer, output.buffer);
    var outputList = output.getDoubleList();
    int maxIndex = outputList
        .indexWhere((e) => e == outputList.reduce((a, b) => a > b ? a : b));
    setState(() {
      _prediction = _labels[maxIndex];
    });
  }

  Future<TensorImage> _convertYUV420ToImageTensor(CameraImage image) async {
    final int width = image.width;
    final int height = image.height;

    final img.Image convertedImage = img.Image(width, height); // RGB 8 bits

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
        final int index = y * width + x;

        final int yp = image.planes[0].bytes[index];
        final int up = image.planes[1].bytes[uvIndex];
        final int vp = image.planes[2].bytes[uvIndex];

        final int r = (yp + 1.370705 * (vp - 128)).clamp(0, 255).toInt();
        final int g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
            .clamp(0, 255)
            .toInt();
        final int b = (yp + 1.732446 * (up - 128)).clamp(0, 255).toInt();

        convertedImage.setPixel(x, y, img.getColor(r, g, b));
      }
    }

    // Redimensionar la imagen a 224x224
    final img.Image resized =
        img.copyResize(convertedImage, width: 224, height: 224);

    // Crear TensorImage
    final TensorImage tensorImage = TensorImage(TfLiteType.float32);
    tensorImage.loadImage(resized);

    // Normalizar (como en el entrenamiento: 0–1)
    final ImageProcessor processor = ImageProcessorBuilder()
        .add(ResizeOp(224, 224, ResizeMethod.BILINEAR))
        .add(NormalizeOp(0, 255)) // <- convierte valores de 0-255 a 0-1
        .build();

    return processor.process(tensorImage);
  }

  void _switchCamera() async {
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    await _controller.stopImageStream();
    await _controller.dispose();
    _initializeCamera();
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
          ? Stack(
              children: [
                CameraPreview(_controller),
                Positioned(
                  bottom: 50,
                  left: 20,
                  child: Text(
                    _prediction,
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                )
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: _switchCamera,
        child: const Icon(Icons.cameraswitch),
      ),
    );
  }
}
*/