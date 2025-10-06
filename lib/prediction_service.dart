import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  final String label;
  final double confidence;

  PredictionResult(this.label, this.confidence);

  @override
  String toString() => "$label (${(confidence * 100).toStringAsFixed(2)}%)";
}

class PredictionService {
  late Interpreter _interpreter;
  late Map<String, String> _labels;
  late List<double> _mean;
  late List<double> _scale;
  bool _loaded = false;

  Future<void> loadModel() async {
    // Cargar modelo
    _interpreter =
        await Interpreter.fromAsset('assets/models/sign_model.tflite');

    // Cargar labels
    final jsonStr = await rootBundle.loadString('assets/labels.json');
    final List<dynamic> rawLabels = json.decode(jsonStr);
    _labels = {
      for (var i = 0; i < rawLabels.length; i++) i.toString(): rawLabels[i]
    };

    // Cargar scaler params
    final scalerStr = await rootBundle.loadString('assets/scaler_params.json');
    final scalerParams = json.decode(scalerStr);
    _mean = List<double>.from(
        scalerParams["mean"].map((e) => (e as num).toDouble()));
    _scale = List<double>.from(
        scalerParams["scale"].map((e) => (e as num).toDouble()));

    _loaded = true;
  }

  bool get isLoaded => _loaded;

  // === Normalización landmarks EXACTA como en Python ===
  List<double> normalizeLandmarks(List<List<double>> landmarks) {
    if (landmarks.isEmpty || landmarks.length != 21) {
      print("⚠️ Landmarks inválidos: length=${landmarks.length}, esperado=21");
      return List.filled(63, 0.0); // 21 landmarks * 3 coords = 63
    }

    // Convertir a lista de coordenadas (como en Python)
    final coords = landmarks.map((lm) => [lm[0], lm[1], lm[2]]).toList();
    
    // Obtener wrist (landmark 0) - EXACTO como Python
    final wrist = [coords[0][0], coords[0][1], coords[0][2]];
    
    // Restar wrist de todos los landmarks - EXACTO como Python
    for (int i = 0; i < coords.length; i++) {
      coords[i][0] -= wrist[0];
      coords[i][1] -= wrist[1];
      coords[i][2] -= wrist[2];
    }
    
    // Calcular escala usando landmark 9 - EXACTO como Python
    final landmark9 = coords[9];
    double scale = sqrt(landmark9[0] * landmark9[0] + 
                       landmark9[1] * landmark9[1] + 
                       landmark9[2] * landmark9[2]);
    
    // Si la escala es muy pequeña, usar la máxima norma - EXACTO como Python
    if (scale <= 1e-6) {
      scale = 0.0;
      for (var coord in coords) {
        final norm = sqrt(coord[0] * coord[0] + coord[1] * coord[1] + coord[2] * coord[2]);
        if (norm > scale) scale = norm;
      }
      if (scale <= 1e-6) scale = 1.0;
    }
    
    // Normalizar por la escala - EXACTO como Python
    for (int i = 0; i < coords.length; i++) {
      coords[i][0] /= scale;
      coords[i][1] /= scale;
      coords[i][2] /= scale;
    }
    
    // Aplanar la lista (flatten) como en Python
    final result = coords.expand((coord) => coord).toList();
    
    // Debug: verificar que el resultado tiene 63 elementos
    if (result.length != 63) {
      print("⚠️ Error en normalización: length=${result.length}, esperado=63");
    }
    
    return result;
  }

  PredictionResult? predict(
      List<double> inputVector, int numHandsDetected) {
    if (!_loaded) {
      print("❌ Modelo no cargado");
      return null;
    }

    print("🔍 === INICIO PREDICCIÓN ===");
    print("🔍 Input vector original length: ${inputVector.length}");
    print("🔍 Num hands detected: $numHandsDetected");
    print("🔍 Input vector primeros 20: ${inputVector.take(20).toList()}");

    // Agregar numHandsDetected
    final extendedVector = List<double>.from(inputVector)
      ..add(numHandsDetected.toDouble());

    print("🔍 Extended vector length: ${extendedVector.length}");
    print("🔍 Extended vector últimos 5: ${extendedVector.skip(extendedVector.length - 5).toList()}");

    // Validar input shape
    final inputShape = _interpreter.getInputTensor(0).shape;
    final expectedSize = inputShape[1];
    print("🔍 Modelo espera: $expectedSize features");
    print("🔍 Tenemos: ${extendedVector.length} features");
    
    if (extendedVector.length != expectedSize) {
      print("❌ ERROR: Tamaño de entrada inválido: se esperaba $expectedSize, se recibió ${extendedVector.length}");
      return null;
    }

    // 🔑 Estandarizar con scaler.pkl
    print("🔍 Escalando con mean/scale...");
    print("🔍 Mean length: ${_mean.length}, Scale length: ${_scale.length}");
    
    final normalized = List<double>.generate(
      extendedVector.length,
      (i) => (extendedVector[i] - _mean[i]) / _scale[i],
    );

    print("🔍 Normalized primeros 10: ${normalized.take(10).toList()}");
    print("🔍 Normalized últimos 5: ${normalized.skip(normalized.length - 5).toList()}");

    // Verificar si hay valores NaN o infinitos
    bool hasNaN = normalized.any((val) => val.isNaN);
    bool hasInfinite = normalized.any((val) => val.isInfinite);
    print("🔍 ¿Hay NaN?: $hasNaN, ¿Hay infinitos?: $hasInfinite");

    if (hasNaN || hasInfinite) {
      print("❌ ERROR: Valores inválidos en normalized vector");
      return null;
    }

    // Preparar input/output
    final input = [normalized];
    final output = [List.filled(_labels.length, 0.0)];

    print("🔍 Ejecutando modelo...");
    
    try {
      // Ejecutar modelo
      _interpreter.run(input, output);
      
      final predictions = output[0];
      print("🔍 Raw predictions (primeros 10): ${predictions.take(10).toList()}");
      
      // Encontrar la predicción con mayor confianza
      double maxConfidence = predictions[0];
      int predictedIndex = 0;
      
      for (int i = 1; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          predictedIndex = i;
        }
      }

      final label = _labels[predictedIndex.toString()] ?? "Desconocido";

      print("🔍 === RESULTADO ===");
      print("🔍 Predicted index: $predictedIndex");
      print("🔍 Predicted label: $label");
      print("🔍 Confidence: $maxConfidence");
      print("🔍 Top 5 predicciones:");
      
      // Mostrar top 5 predicciones
      List<MapEntry<int, double>> sortedPredictions = [];
      for (int i = 0; i < predictions.length; i++) {
        sortedPredictions.add(MapEntry(i, predictions[i]));
      }
      sortedPredictions.sort((a, b) => b.value.compareTo(a.value));
      
      for (int i = 0; i < 5 && i < sortedPredictions.length; i++) {
        final idx = sortedPredictions[i].key;
        final conf = sortedPredictions[i].value;
        final lbl = _labels[idx.toString()] ?? "Desconocido";
        print("🔍   ${i + 1}. $lbl: ${conf.toStringAsFixed(4)}");
      }
      
      print("🔍 === FIN PREDICCIÓN ===");

      return PredictionResult(label, maxConfidence);
      
    } catch (e) {
      print("❌ ERROR ejecutando modelo: $e");
      return null;
    }
  }

  void dispose() {
    _interpreter.close();
  }
}
