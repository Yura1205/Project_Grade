#!/usr/bin/env python3
"""
Script para generar datos de prueba que funcionen en Python
y luego probar en Flutter para comparar
"""
import json
import numpy as np

def generate_test_landmarks():
    """Generar landmarks de prueba realistas"""
    # Simular una mano en posición "A" (puño cerrado)
    # Basado en las proporciones típicas de MediaPipe
    
    # Wrist (0)
    landmarks = [[0.5, 0.5, 0.0]]
    
    # Thumb (1-4)
    landmarks.extend([
        [0.52, 0.48, -0.01],  # CMC
        [0.54, 0.46, -0.02],  # MCP  
        [0.55, 0.44, -0.025], # IP
        [0.56, 0.42, -0.03]   # TIP
    ])
    
    # Index finger (5-8) - cerrado
    landmarks.extend([
        [0.55, 0.52, -0.01],  # MCP
        [0.56, 0.54, -0.015], # PIP
        [0.57, 0.55, -0.02],  # DIP
        [0.58, 0.56, -0.025]  # TIP
    ])
    
    # Middle finger (9-12) - cerrado
    landmarks.extend([
        [0.52, 0.53, -0.01],  # MCP
        [0.53, 0.55, -0.015], # PIP
        [0.54, 0.57, -0.02],  # DIP
        [0.55, 0.58, -0.025]  # TIP
    ])
    
    # Ring finger (13-16) - cerrado  
    landmarks.extend([
        [0.49, 0.52, -0.01],  # MCP
        [0.48, 0.54, -0.015], # PIP
        [0.47, 0.56, -0.02],  # DIP
        [0.46, 0.57, -0.025]  # TIP
    ])
    
    # Pinky (17-20) - cerrado
    landmarks.extend([
        [0.46, 0.51, -0.01],  # MCP
        [0.45, 0.53, -0.015], # PIP
        [0.44, 0.54, -0.02],  # DIP
        [0.43, 0.55, -0.025]  # TIP
    ])
    
    return landmarks

def normalize_landmarks_python(landmarks):
    """Normalizar landmarks exactamente como en Python"""
    coords = np.array(landmarks, dtype=np.float32)
    
    # Obtener wrist y restar
    wrist = coords[0].copy()
    coords -= wrist
    
    # Calcular escala usando landmark 9
    scale = np.linalg.norm(coords[9])
    if scale <= 1e-6:
        scale = np.max(np.linalg.norm(coords, axis=1))
        if scale <= 1e-6:
            scale = 1.0
    
    # Normalizar
    coords /= scale
    
    return coords.flatten().tolist()

def create_flutter_test_data():
    """Crear datos de prueba para Flutter"""
    print("🧪 Generando datos de prueba...")
    
    # Generar landmarks para una mano
    landmarks = generate_test_landmarks()
    print(f"✅ Generados {len(landmarks)} landmarks")
    
    # Normalizar como en Python
    normalized = normalize_landmarks_python(landmarks)
    print(f"✅ Normalizado: {len(normalized)} valores")
    print(f"   Primeros 10: {normalized[:10]}")
    
    # Crear vector completo (padding para 2 manos + numHands)
    full_vector = normalized + [0.0] * 63  # padding para segunda mano
    full_vector.append(1.0)  # numHands = 1
    
    print(f"✅ Vector completo: {len(full_vector)} valores")
    
    # Crear datos de prueba en formato JSON
    test_data = {
        "description": "Datos de prueba para señal 'A' - puño cerrado",
        "landmarks_raw": landmarks,
        "landmarks_normalized": normalized,
        "full_vector": full_vector,
        "num_hands": 1,
        "expected_label": "A",
        "notes": "Usar estos datos exactos en Flutter para verificar que el pipeline funciona igual"
    }
    
    # Guardar en archivo
    with open("test_data.json", "w") as f:
        json.dump(test_data, f, indent=2)
    
    print("✅ Datos guardados en test_data.json")
    
    # Imprimir código Flutter para copiar/pegar
    print("\n" + "="*60)
    print("📱 CÓDIGO PARA FLUTTER (copia y pega en tu app):")
    print("="*60)
    
    flutter_code = f"""
// Test con datos conocidos - agregar en _processCameraImage
void testWithKnownData() {{
  // Datos generados desde Python que deberían dar "A"
  List<double> testVector = {str(full_vector).replace("'", "")};
  
  print("🧪 TESTING con datos conocidos...");
  print("🧪 Vector length: ${{testVector.length}}");
  
  final prediction = _predictionService.predict(testVector.sublist(0, 126), 1);
  
  if (prediction != null) {{
    print("🧪 RESULTADO TEST:");
    print("🧪 Label: ${{prediction.label}}");
    print("🧪 Confidence: ${{prediction.confidence}}");
    print("🧪 ¿Es 'A'?: ${{prediction.label == 'A'}}");
  }} else {{
    print("🧪 ERROR: No se pudo hacer predicción");
  }}
}}
"""
    
    print(flutter_code)
    
    return test_data

if __name__ == "__main__":
    create_flutter_test_data()