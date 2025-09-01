import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionService {
  late Interpreter _interpreter;
  late Map<String, String> _labels;
  bool _loaded = false;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('models/sign_model.tflite');
    final jsonStr = await rootBundle.loadString('assets/labels.json');
    _labels = Map<String, String>.from(json.decode(jsonStr));
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  Future<String> predict(List<double> inputVector) async {
    if (!_loaded) return "Modelo no cargado";

    final input = [inputVector];
    final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

    _interpreter.run(input, output);

    final predictedIndex = (output[0] as List<double>)
        .asMap()
        .entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return _labels[predictedIndex.toString()] ?? "Desconocido";
  }

  void dispose() {
    _interpreter.close();
  }
}
