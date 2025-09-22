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
  bool _loaded = false;

  late Map<String, int> _labelNumHands;

  Future<void> loadModel() async {
    _interpreter =
        await Interpreter.fromAsset('assets/models/sign_model.tflite');

    final jsonStr = await rootBundle.loadString('assets/labels.json');
    _labels = Map<String, String>.from(json.decode(jsonStr));

    final jsonNumHands =
        await rootBundle.loadString('assets/labels_numhands.json');
    _labelNumHands = Map<String, int>.from(json.decode(jsonNumHands));

    _loaded = true;
  }

  bool get isLoaded => _loaded;

  /// Normaliza landmarks como en Python:
  /// - resta la muñeca (landmark 0)
  /// - divide entre la norma del landmark 9
  List<double> normalizeLandmarks(List<List<double>> landmarks) {
    if (landmarks.isEmpty) return [];

    final wrist = landmarks[0];
    final shifted = landmarks
        .map((lm) => [
              lm[0] - wrist[0],
              lm[1] - wrist[1],
              lm[2] - wrist[2],
            ])
        .toList();

    final ref = shifted[9]; // landmark 9 (base dedo medio)
    final scale = sqrt(ref[0] * ref[0] + ref[1] * ref[1] + ref[2] * ref[2]);

    if (scale > 0) {
      for (var lm in shifted) {
        lm[0] /= scale;
        lm[1] /= scale;
        lm[2] /= scale;
      }
    }

    // Aplanar
    return shifted.expand((e) => e).toList();
  }

  Future<PredictionResult?> predict(List<double> inputVector, int numHandsDetected) async {
    if (!_loaded) return null;

    // === Validar input shape ===
    final inputShape = _interpreter.getInputTensor(0).shape; // ej: [1,126]
    final expectedSize = inputShape[1];
    if (inputVector.length != expectedSize) {
      throw Exception(
          "Tamaño de entrada inválido: se esperaba $expectedSize, se recibió ${inputVector.length}");
    }

    // === Preparar input ===
    final input = [inputVector];
    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    // === Ejecutar modelo ===
    _interpreter.run(input, output);

    // === Obtener predicción ===
    final predictions = output[0] as List<double>;
    final predictedIndex = predictions
        .asMap()
        .entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final confidence = predictions[predictedIndex];

    final label = _labels[predictedIndex.toString()] ?? "Desconocido";

    // 🔑 Validar número de manos
    final requiredHands = _labelNumHands[label] ?? 1;
    if (numHandsDetected != requiredHands) {
      return PredictionResult("N/A", 0.0);
    }

    return PredictionResult(label, confidence);
  }

  void dispose() {
    _interpreter.close();
  }
}
