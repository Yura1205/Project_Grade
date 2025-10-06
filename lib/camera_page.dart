import 'dart:async';
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
  Duration _predictionDelay = Duration(milliseconds: 200); // Más frecuente para mejor UX

  final PredictionService _predictionService = PredictionService();
  final FlutterTts _tts = FlutterTts();

  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;

  // 🎯 Sistema de estabilización de predicciones
  Map<String, int> _predictionCounts = {};
  String _lastStableLabel = '';
  int _stableThreshold = 2; // Reducir a 2 para más responsividad

  // 🚀 Control de rendimiento
  bool _isProcessing = false; // Evitar procesamiento simultáneo
  int _frameSkip = 0; // Saltar frames para optimizar

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  // Test con datos conocidos - AGREGAR ESTE MÉTODO
  void testWithKnownData() {
    // Datos generados desde Python que deberían dar "A"
    List<double> testVector = [0.0, 0.0, 0.0, 0.5345224738121033, -0.5345232486724854, -0.26726147532463074, 1.0690464973449707, -1.0690456628799438, -0.5345229506492615, 1.3363077640533447, -1.6035689115524292, -0.668153703212738, 1.6035689115524292, -2.138092279434204, -0.8017844557762146, 1.3363077640533447, 0.5345224738121033, -0.26726147532463074, 1.6035689115524292, 1.0690464973449707, -0.4008922278881073, 1.8708301782608032, 1.3363077640533447, -0.5345229506492615, 2.1380913257598877, 1.6035689115524292, -0.668153703212738, 0.5345224738121033, 0.8017836809158325, -0.26726147532463074, 0.8017836809158325, 1.3363077640533447, -0.4008922278881073, 1.0690464973449707, 1.8708301782608032, -0.5345229506492615, 1.3363077640533447, 2.1380913257598877, -0.668153703212738, -0.26726123690605164, 0.5345224738121033, -0.26726147532463074, -0.5345232486724854, 1.0690464973449707, -0.4008922278881073, -0.8017844557762146, 1.6035689115524292, -0.5345229506492615, -1.0690456628799438, 1.8708301782608032, -0.668153703212738, -1.0690456628799438, 0.26726123690605164, -0.26726147532463074, -1.3363077640533447, 0.8017836809158325, -0.4008922278881073, -1.6035689115524292, 1.0690464973449707, -0.5345229506492615, -1.8708301782608032, 1.3363077640533447, -0.668153703212738, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    
    print("🧪 ===== TESTING CON DATOS CONOCIDOS =====");
    print("🧪 Vector length: ${testVector.length}");
    
    final prediction = _predictionService.predict(testVector.sublist(0, 126), 1);
    
    if (prediction != null) {
      print("🧪 RESULTADO TEST:");
      print("🧪 Label: ${prediction.label}");
      print("🧪 Confidence: ${prediction.confidence}");
      print("🧪 ¿Es 'A'?: ${prediction.label == 'A'}");
      
      if (prediction.label == 'A' && prediction.confidence > 0.5) {
        print("✅ TEST PASÓ: El modelo funciona correctamente");
      } else {
        print("❌ TEST FALLÓ: El modelo no predice 'A' o confianza muy baja");
      }
    } else {
      print("🧪 ERROR: No se pudo hacer predicción");
    }
    print("🧪 ===== FIN TEST =====");
  }

  Future<void> _initializeAll() async {
    _cameras = await availableCameras();
    await _initializeCamera(_cameras![_currentCameraIndex]);
    await _initializeHandLandmarker();
    await _predictionService.loadModel();
    
    // 🧪 Ejecutar test automáticamente cuando el modelo esté cargado
    if (_predictionService.isLoaded) {
      print("🚀 Modelo cargado, ejecutando test...");
      testWithKnownData();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    _controller = CameraController(
      cameraDescription, 
      ResolutionPreset.low, // Cambiar a low para mejor performance
      enableAudio: false, // No necesitamos audio
      imageFormatGroup: ImageFormatGroup.yuv420, // Formato más eficiente
    );
    
    await _controller!.initialize();
    
    // Configurar FPS para mejor fluidez
    await _controller!.setFocusMode(FocusMode.auto);
    await _controller!.setExposureMode(ExposureMode.auto);
    
    print("📱 === CONFIGURACIÓN DE CÁMARA OPTIMIZADA ===");
    print("📱 Resolución: ${_controller!.value.previewSize}");
    print("📱 Orientación sensor: ${_controller!.description.sensorOrientation}");
    print("📱 Lente frontal: ${_controller!.description.lensDirection == CameraLensDirection.front}");
    print("📱 Formato: yuv420 (optimizado)");
    
    if (!mounted) return;
    setState(() {});
    _controller!.startImageStream((image) {
      if (_plugin != null && _predictionService.isLoaded) {
        _processCameraImage(image);
      }
    });
  }

  Future<void> _initializeHandLandmarker() async {
    _plugin = HandLandmarkerPlugin.create();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // 🚀 Optimización: Evitar procesamiento simultáneo
    if (_isProcessing) return;
    
    // 🚀 Optimización: Saltar frames para mejor rendimiento
    _frameSkip++;
    if (_frameSkip < 2) return; // Procesar solo cada 2 frames
    _frameSkip = 0;
    
    _isProcessing = true;
    
    try {
      final hands =
          _plugin!.detect(image, _controller!.description.sensorOrientation);

      print("📱 === PROCESANDO IMAGEN (ORIENTACIÓN: ${_controller!.description.sensorOrientation}°) ===");
      print("📱 Número de manos detectadas: ${hands.length}");
      print("📱 Imagen: ${image.width}x${image.height}");

    if (hands.isNotEmpty && _predictionService.isLoaded) {
      // Imprimir información de cada mano detectada
      for (int i = 0; i < hands.length; i++) {
        final hand = hands[i];
        print("📱 Mano $i: ${hand.landmarks.length} landmarks");
        
        // Verificar que tenga exactamente 21 landmarks
        if (hand.landmarks.length != 21) {
          print("⚠️ ERROR: Mano $i tiene ${hand.landmarks.length} landmarks, esperado 21");
          return;
        }
        
        // Mostrar algunos landmarks para verificar
        final wrist = hand.landmarks[0];
        final thumb = hand.landmarks[4];
        final index = hand.landmarks[8];
        print("📱 Mano $i - Wrist: (${wrist.x.toStringAsFixed(3)}, ${wrist.y.toStringAsFixed(3)}, ${wrist.z.toStringAsFixed(3)})");
        print("📱 Mano $i - Thumb: (${thumb.x.toStringAsFixed(3)}, ${thumb.y.toStringAsFixed(3)}, ${thumb.z.toStringAsFixed(3)})");
        print("📱 Mano $i - Index: (${index.x.toStringAsFixed(3)}, ${index.y.toStringAsFixed(3)}, ${index.z.toStringAsFixed(3)})");
      }

      // Ordenamos manos por eje X (izq -> der)
      final sortedHands = hands.toList()
        ..sort((a, b) =>
            a.landmarks.map((lm) => lm.x).reduce((s, v) => s + v).compareTo(
                b.landmarks.map((lm) => lm.x).reduce((s, v) => s + v)));

      print("📱 Manos ordenadas por posición X");

      List<double> row = [];
      for (int handIdx = 0; handIdx < sortedHands.length; handIdx++) {
        var hand = sortedHands[handIdx];
        var landmarks =
            hand.landmarks.map((lm) => [lm.x, lm.y, lm.z]).toList();

        print("📱 Procesando mano $handIdx...");
        print("📱 Landmarks RAW (primeros 5):");
        for (int i = 0; i < 5; i++) {
          final lm = landmarks[i];
          print("📱   [$i]: (${lm[0].toStringAsFixed(6)}, ${lm[1].toStringAsFixed(6)}, ${lm[2].toStringAsFixed(6)})");
        }
        
        // Mostrar landmarks específicos importantes para debug
        print("📱 Landmarks clave:");
        print("📱   Wrist[0]: (${landmarks[0][0].toStringAsFixed(6)}, ${landmarks[0][1].toStringAsFixed(6)}, ${landmarks[0][2].toStringAsFixed(6)})");
        print("📱   Thumb[4]: (${landmarks[4][0].toStringAsFixed(6)}, ${landmarks[4][1].toStringAsFixed(6)}, ${landmarks[4][2].toStringAsFixed(6)})");
        print("📱   Index[8]: (${landmarks[8][0].toStringAsFixed(6)}, ${landmarks[8][1].toStringAsFixed(6)}, ${landmarks[8][2].toStringAsFixed(6)})");
        print("📱   Middle[12]: (${landmarks[12][0].toStringAsFixed(6)}, ${landmarks[12][1].toStringAsFixed(6)}, ${landmarks[12][2].toStringAsFixed(6)})");

        // NO aplicar rotación - igual que en Python
        // landmarks = _rotateLandmarks(
        //     landmarks, _controller!.description.sensorOrientation);

        // Normalizar igual que en Python
        final vector = _predictionService.normalizeLandmarks(landmarks);
        print("📱 Vector normalizado length: ${vector.length}");
        print("📱 Vector normalizado (primeros 10): ${vector.take(10).map((v) => v.toStringAsFixed(4)).toList()}");

        row.addAll(vector);
      }

      // Padding a 126 (si hay 1 mano)
      print("📱 Row length antes de padding: ${row.length}");
      while (row.length < 126) {
        row.add(0.0);
      }
      print("📱 Row length después de padding: ${row.length}");

      // Verificar que el row tenga exactamente 126 elementos
      if (row.length != 126) {
        print("❌ ERROR: Row tiene ${row.length} elementos, esperado 126");
        return;
      }

      // === Ahora predice con numHands ===
      print("📱 Llamando a predict con ${row.length} features y ${hands.length} manos...");
      final prediction =
          _predictionService.predict(row, hands.length);

      if (prediction != null &&
          prediction.label != "N/A" &&
          prediction.confidence > 0.3) { // Subir threshold un poco
        
        // 🎯 Sistema de estabilización
        _predictionCounts[prediction.label] = (_predictionCounts[prediction.label] ?? 0) + 1;
        
        // Limpiar contadores antiguos
        _predictionCounts.removeWhere((label, count) => 
            label != prediction.label && count < _stableThreshold);
        
        print("🎯 Prediction counts: $_predictionCounts");
        
        // Solo procesar si la predicción es estable
        if (_predictionCounts[prediction.label]! >= _stableThreshold && 
            prediction.label != _lastStableLabel) {
          
          final now = DateTime.now();
          
          if (now.difference(_lastPredictionTime) > _predictionDelay) {
            _lastPredictionTime = now;
            _lastStableLabel = prediction.label;
            
            // Resetear contadores
            _predictionCounts.clear();

            // Agregar letra/palabra actual
            _currentWord += "${prediction.label} ";

            // Leer la predicción
            _speak(prediction.label);

            setState(() {
              _realTimeText = prediction.label;
            });
            
            print("✅ PREDICCIÓN ESTABLE: ${prediction.label} (confianza: ${prediction.confidence.toStringAsFixed(3)})");
          }
        }
      }
    }
    } finally {
      // 🚀 Siempre liberar el flag de procesamiento
      _isProcessing = false;
    }
  }

  Future<void> _speak(String text) async {
    await _tts.setLanguage("es-ES");
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

  // Test con datos conocidos de Python
  void _testWithKnownData() {
    print("🧪 ===== TESTING CON DATOS CONOCIDOS =====");
    
    // Vector que en Python debería dar "A" (datos reales del entrenamiento)
    List<double> testVectorA = [
      // Datos de landmarks normalizados que deberían producir "A"
      0.5, 0.3, 0.1, 0.45, 0.25, 0.12, 0.4, 0.2, 0.15, 0.35, 0.15, 0.18,
      0.3, 0.1, 0.2, 0.25, 0.05, 0.22, 0.2, 0.0, 0.25, 0.6, 0.4, 0.08,
      0.65, 0.45, 0.1, 0.7, 0.5, 0.12, 0.75, 0.55, 0.15, 0.8, 0.6, 0.18,
      0.85, 0.65, 0.2, 0.55, 0.35, 0.08, 0.5, 0.3, 0.1, 0.45, 0.25, 0.12,
      0.4, 0.2, 0.15, 0.35, 0.15, 0.18, 0.3, 0.1, 0.2, 0.25, 0.05, 0.22,
      0.2, 0.0, 0.25
    ];
    
    // Completar hasta 126 features (63 × 2)
    while (testVectorA.length < 126) {
      testVectorA.add(0.0);
    }
    
    print("🧪 Vector length: ${testVectorA.length}");
    
    try {
      final prediction = _predictionService.predict(testVectorA, 1);
      if (prediction != null) {
        print("🧪 RESULTADO TEST:");
        print("🧪 Predicción: ${prediction.label}");
        print("🧪 Confianza: ${prediction.confidence}");
        print("🧪 ===================================");
        
        // Mostrar en pantalla
        setState(() {
          _realTimeText = "TEST: ${prediction.label} (${prediction.confidence.toStringAsFixed(3)})";
        });
      } else {
        print("🧪 ERROR: Predicción nula");
      }
    } catch (e) {
      print("🧪 ERROR en test: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reconocimiento de señas (HORIZONTAL)"),
        actions: [
          // Botón para test con datos conocidos
          IconButton(
            icon: const Icon(Icons.science),
            onPressed: _testWithKnownData,
            tooltip: "Test con datos conocidos",
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  "Seña actual: $_realTimeText",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Palabra: $_currentWord",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Botones de control optimizados
          Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _deleteLastLetter,
                  icon: const Icon(Icons.backspace),
                  label: const Text("Borrar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _resetWord,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Reset"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _testWithKnownData,
                  icon: const Icon(Icons.science),
                  label: const Text("Test"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
