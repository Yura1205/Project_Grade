import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'history_page.dart'; // Asegúrate de tener este archivo creado

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
  bool _modelLoaded = false; // <- NUEVO: bandera para saber si todo está listo
  final List<Map<String, String>> _history = [];

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
    } catch (e) {
      print("Error cargando modelo o etiquetas: $e");
    }
  }

  Future<void> _captureAndClassify() async {
    if (_isProcessing || !_modelLoaded) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final file = await _controller.takePicture();
      final prediction = await _predictImage(File(file.path));
      await _showPopup(prediction, File(file.path));
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        _isProcessing = false;
      });
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
    print(output[0]);

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
        title: const Text("Resultado"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(File(imagePath), height: 200),
            const SizedBox(height: 12),
            Text("Seña detectada: $prediction"),
          ],
        ),
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
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Cámara de Señas")),
      body: CameraPreview(_controller),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FloatingActionButton(
            heroTag: 'capture',
            child: const Icon(Icons.pan_tool),
            backgroundColor: _modelLoaded && !_isProcessing
                ? Colors.deepPurple
                : Colors.grey,
            onPressed:
                (_modelLoaded && !_isProcessing) ? _captureAndClassify : null,
          ),
          FloatingActionButton(
            heroTag: 'history',
            child: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(history: _history),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
