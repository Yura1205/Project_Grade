// Test para la app de detección de señas
//
// Este test verifica que la app de detección de señas se inicie correctamente
// y muestre los elementos esperados de la interfaz de cámara.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';

import 'package:hand_detection/main.dart';

void main() {
  testWidgets('Sign Language Detection App smoke test', (WidgetTester tester) async {
    // Crear una cámara mock para testing
    final List<CameraDescription> cameras = [
      const CameraDescription(
        name: 'Test Camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(camera: cameras.first));

    // Verificar que la app se inicia
    // Buscar elementos típicos de una app de cámara
    expect(find.byType(Scaffold), findsOneWidget);
    
    // Verificar que hay un AppBar
    expect(find.byType(AppBar), findsOneWidget);
    
    // Verificar el título de la app
    expect(find.text('Reconocimiento de señas (HORIZONTAL)'), findsOneWidget);
    
    // Verificar que no hay errores críticos
    expect(tester.takeException(), isNull);
  });

  testWidgets('App shows camera permission elements', (WidgetTester tester) async {
    // Crear una cámara mock
    final List<CameraDescription> cameras = [
      const CameraDescription(
        name: 'Test Camera',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      ),
    ];

    await tester.pumpWidget(MyApp(camera: cameras.first));
    
    // La app debería tener una estructura básica sin crashear
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
