import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'history_page.dart';
import 'package:flutter_mediapipe/flutter_mediapipe.dart';
import 'package:flutter_mediapipe/gen/landmark.pb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lengua de Señas',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late Interpreter _interpreter;
  late Map<String, String> _labels;
  bool _modelLoaded = false;
  bool _isProcessing = false;
  bool _isRealTimeEnabled = false;
  final List<Map<String, String>> _history = [];

  String _realTimeText = '';
  String _lastPrediction = '';

  late FlutterMediapipe _mediapipe;

  @override
  void initState() {
    super.initState();
    _loadModel();
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

  void _onMediapipeCreated(FlutterMediapipe controller) {
    _mediapipe = controller;

    // escuchar landmarks
    _mediapipe.landMarksStream.listen((NormalizedLandmarkList list) async {
      if (_isRealTimeEnabled && !_isProcessing && _modelLoaded) {
        _isProcessing = true;
        try {
          final prediction = await _predictLandmarks(list);

          if (prediction != _lastPrediction) {
            _lastPrediction = prediction;
            setState(() {
              _realTimeText = prediction;
              _history.add({'label': prediction});
              if (_history.length > 20) _history.removeAt(0);
            });
          }
        } catch (e) {
          print("Error en predicción: $e");
        } finally {
          _isProcessing = false;
        }
      }
    });
  }

  Future<String> _predictLandmarks(NormalizedLandmarkList list) async {
    if (!_modelLoaded) return "Modelo no cargado";
    if (list.landmark.length != 21) return "Landmarks inválidos";

    // tensor [1,63]
    final input = List.generate(1, (_) {
      return list.landmark
          .map((lm) => [lm.x, lm.y, lm.z])
          .expand((coords) => coords)
          .toList();
    });

    final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);
    _interpreter.run(input, output);

    final predictedIndex = (output[0] as List<double>)
        .asMap()
        .entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return _labels[predictedIndex.toString()] ?? "Desconocido";
  }

  @override
  void dispose() {
    _interpreter.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // vista previa de cámara con mediapipe
          NativeView(onViewCreated: _onMediapipeCreated),

          // título
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

          // traducción
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
                // botón on/off
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
                    },
                  ),
                ),
              ],
            ),
          ),

          // botón historial
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
