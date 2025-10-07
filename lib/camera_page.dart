import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // 🧭 Detección de orientación automática
  DeviceOrientation _currentOrientation = DeviceOrientation.portraitUp;

  // 🎨 Control de tema
  bool _isDarkMode = true; // Comenzar en modo oscuro

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeOrientationListener();
  }

  // 🧭 Inicializar listener de orientación
  void _initializeOrientationListener() {
    // Obtener orientación inicial cuando el contexto esté disponible
    _updateOrientation();
  }

  // 🧭 Actualizar orientación actual
  void _updateOrientation() {
    if (mounted) {
      final MediaQueryData mediaQuery = MediaQuery.of(context);
      final Size size = mediaQuery.size;
      final double width = size.width;
      final double height = size.height;
      
      // Determinar orientación basada en dimensiones reales
      if (height > width) {
        // Más alto que ancho = Portrait
        _currentOrientation = DeviceOrientation.portraitUp;
      } else {
        // Más ancho que alto = Landscape  
        _currentOrientation = DeviceOrientation.landscapeLeft;
      }
      
      print("🧭 Orientación detectada: $_currentOrientation (${width.toInt()}x${height.toInt()})");
    }
  }

  // 🧭 Compensar orientación de landmarks automáticamente
  List<List<double>> _compensateOrientation(List<List<double>> landmarks) {
    print("🧭 Aplicando compensación para orientación: $_currentOrientation");
    
    // Si estamos en portrait, los landmarks ya están correctos (orientación base del modelo)
    if (_currentOrientation == DeviceOrientation.portraitUp) {
      print("🧭 Portrait: No se requiere compensación");
      return landmarks;
    }

    // Crear una copia de landmarks para no modificar el original
    List<List<double>> compensatedLandmarks = landmarks
        .map((landmark) => List<double>.from(landmark))
        .toList();

    print("🧭 Landmarks antes de compensación (primeros 3):");
    for (int i = 0; i < math.min(3, landmarks.length); i++) {
      print("🧭   [$i]: (${landmarks[i][0].toStringAsFixed(3)}, ${landmarks[i][1].toStringAsFixed(3)}, ${landmarks[i][2].toStringAsFixed(3)})");
    }

    // Aplicar rotación según la orientación detectada
    for (int i = 0; i < compensatedLandmarks.length; i++) {
      double x = compensatedLandmarks[i][0];
      double y = compensatedLandmarks[i][1];
      // Z no se ve afectado por rotación 2D, se mantiene igual

      switch (_currentOrientation) {
        case DeviceOrientation.landscapeLeft:
          // Para landscape left, necesitamos rotar los puntos 
          // Como si rotáramos la imagen 90° antihorario
          compensatedLandmarks[i][0] = 1.0 - y;
          compensatedLandmarks[i][1] = x;
          break;
        case DeviceOrientation.landscapeRight:
          // Para landscape right, rotar 90° horario
          compensatedLandmarks[i][0] = y;
          compensatedLandmarks[i][1] = 1.0 - x;
          break;
        case DeviceOrientation.portraitDown:
          // Rotar 180°: (x,y) -> (1-x, 1-y)
          compensatedLandmarks[i][0] = 1.0 - x;
          compensatedLandmarks[i][1] = 1.0 - y;
          break;
        default:
          // portraitUp - no cambiar
          break;
      }
    }

    print("🧭 Landmarks después de compensación (primeros 3):");
    for (int i = 0; i < math.min(3, compensatedLandmarks.length); i++) {
      print("🧭   [$i]: (${compensatedLandmarks[i][0].toStringAsFixed(3)}, ${compensatedLandmarks[i][1].toStringAsFixed(3)}, ${compensatedLandmarks[i][2].toStringAsFixed(3)})");
    }

    return compensatedLandmarks;
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

        // 🧭 Aplicar compensación de orientación automática
        landmarks = _compensateOrientation(landmarks);
        print("📱 Landmarks después de compensación de orientación (primeros 3):");
        for (int i = 0; i < 3; i++) {
          final lm = landmarks[i];
          print("📱   [$i]: (${lm[0].toStringAsFixed(6)}, ${lm[1].toStringAsFixed(6)}, ${lm[2].toStringAsFixed(6)})");
        }

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

  @override
  Widget build(BuildContext context) {
    // 🧭 Actualizar orientación en cada rebuild para detección en tiempo real
    _updateOrientation();
    
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isDarkMode 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF007AFF), // iOS blue
                    strokeWidth: 3,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Iniciando cámara...',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _isDarkMode 
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black.withOpacity(0.8),
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _isDarkMode ? Colors.black : const Color(0xFFF2F2F7),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'SignLang AI',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _isDarkMode ? Colors.white : Colors.black,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          // Toggle de tema en el AppBar
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: _buildThemeToggle(),
          ),
          // Botón de cambiar cámara
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: _buildGlassButton(
              icon: Icons.cameraswitch_outlined,
              onPressed: _switchCamera,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Espaciado superior para el AppBar
            const SizedBox(height: 20),
            
            // Cámara con bordes redondeados estilo iOS
            Expanded(
              flex: 3, // 60% del espacio disponible
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!.height,
                        height: _controller!.value.previewSize!.width,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Espaciado entre cámara y panel
            const SizedBox(height: 20),
            
            // Panel de información con glassmorphism - SIN SUPERPOSICIÓN
            Expanded(
              flex: 2, // 40% del espacio disponible
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _isDarkMode ? [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.95),
                    ] : [
                      Colors.transparent,
                      Colors.white.withOpacity(0.8),
                      Colors.white.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isDarkMode 
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      border: Border.all(
                        color: _isDarkMode 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Indicador de arrastre iOS
                          Container(
                            width: 36,
                            height: 5,
                            decoration: BoxDecoration(
                              color: _isDarkMode 
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Texto de seña detectada
                          _buildInfoCard(
                            title: 'Seña detectada',
                            content: _realTimeText.isEmpty ? 'Esperando...' : _realTimeText,
                            icon: Icons.sign_language_outlined,
                            color: const Color(0xFF34C759), // iOS green
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Texto de palabra construida - SCROLLABLE si es muy largo
                          _buildInfoCard(
                            title: 'Palabra formada',
                            content: _currentWord.isEmpty ? 'Vacía' : _currentWord,
                            icon: Icons.text_fields_outlined,
                            color: const Color(0xFF007AFF), // iOS blue
                            isScrollable: true, // Nueva propiedad para scroll
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Botones de acción con estilo líquido
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.backspace_outlined,
                                  label: 'Borrar',
                                  color: const Color(0xFFFF3B30), // iOS red
                                  onPressed: _deleteLastLetter,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.refresh_outlined,
                                  label: 'Limpiar',
                                  color: const Color(0xFF007AFF), // iOS blue
                                  onPressed: _resetWord,
                                ),
                              ),
                            ],
                          ),
                          // Padding extra para evitar overflow
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para botones de cristal estilo iOS
  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _isDarkMode 
            ? Colors.white.withOpacity(0.15)
            : Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode 
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Icon(
            icon,
            color: _isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
        ),
      ),
    );
  }

  // Widget para toggle de tema estilo iOS - Versión AppBar
  Widget _buildThemeToggle() {
    return Container(
      width: 50,
      height: 28,
      decoration: BoxDecoration(
        color: _isDarkMode 
            ? const Color(0xFF34C759).withOpacity(0.3)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDarkMode 
              ? const Color(0xFF34C759).withOpacity(0.6)
              : Colors.grey.withOpacity(0.6),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _isDarkMode = !_isDarkMode;
            });
          },
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                left: _isDarkMode ? 24 : 2,
                top: 2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white : Colors.black,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    size: 14,
                    color: _isDarkMode ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para tarjetas de información
  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    bool isScrollable = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isDarkMode 
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode 
              ? Colors.white.withOpacity(0.15)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _isDarkMode 
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.7),
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                isScrollable && content.length > 50
                    ? Container(
                        height: 60,
                        child: SingleChildScrollView(
                          child: Text(
                            content,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _isDarkMode ? Colors.white : Colors.black,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        content,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black,
                          letterSpacing: -0.4,
                        ),
                        maxLines: isScrollable ? null : 2,
                        overflow: isScrollable ? null : TextOverflow.ellipsis,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget para botones de acción estilo iOS líquido
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(0.8),
            color.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
