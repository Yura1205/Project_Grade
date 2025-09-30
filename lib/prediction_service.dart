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

  // === Normalización landmarks como en Python ===
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

    final ref = shifted[9]; // landmark 9
    final scaleVal = sqrt(ref[0] * ref[0] + ref[1] * ref[1] + ref[2] * ref[2]);

    if (scaleVal > 0) {
      for (var lm in shifted) {
        lm[0] /= scaleVal;
        lm[1] /= scaleVal;
        lm[2] /= scaleVal;
      }
    }

    return shifted.expand((e) => e).toList();
  }

  Future<PredictionResult?> predict(
      List<double> inputVector, int numHandsDetected) async {
    if (!_loaded) return null;

    // Agregar numHandsDetected
    final extendedVector = List<double>.from(inputVector)
      ..add(numHandsDetected.toDouble());

    // Validar input shape
    final inputShape = _interpreter.getInputTensor(0).shape; // ej: [1,127]
    final expectedSize = inputShape[1];
    if (extendedVector.length != expectedSize) {
      throw Exception(
          "Tamaño de entrada inválido: se esperaba $expectedSize, se recibió ${extendedVector.length}");
    }

    // 🔑 Estandarizar con scaler.pkl
    final normalized = List<double>.generate(
      extendedVector.length,
      (i) => (extendedVector[i] - _mean[i]) / _scale[i],
    );

    // Preparar input/output
    final input = [normalized];
    final output =
        List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    // Ejecutar modelo
    _interpreter.run(input, output);

    final predictions = output[0] as List<double>;
    final predictedIndex = predictions
        .asMap()
        .entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
    final confidence = predictions[predictedIndex];

    final label = _labels[predictedIndex.toString()] ?? "Desconocido";

    return PredictionResult(label, confidence);
  }

  void dispose() {
    _interpreter.close();
  }
}
