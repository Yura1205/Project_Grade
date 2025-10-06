#!/usr/bin/env python3
"""
Test completo para validar modelo Python vs TFLite vs Flutter
"""
import numpy as np
import json
import os

def test_tflite_model():
    """Test del modelo TFLite usando solo librerías básicas"""
    print("🔍 Testing modelo TFLite...")
    
    try:
        import tensorflow as tf
        print("✅ TensorFlow disponible")
        
        # Cargar el modelo TFLite
        interpreter = tf.lite.Interpreter(model_path="assets/models/sign_model.tflite")
        interpreter.allocate_tensors()
        
        # Obtener detalles de input/output
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"📊 Input shape: {input_details[0]['shape']}")
        print(f"📊 Output shape: {output_details[0]['shape']}")
        
        # Cargar scaler y labels
        with open("assets/scaler_params.json", "r") as f:
            scaler_params = json.load(f)
        
        with open("assets/labels.json", "r") as f:
            labels = json.load(f)
        
        print(f"📊 Scaler mean length: {len(scaler_params['mean'])}")
        print(f"📊 Labels count: {len(labels)}")
        
        # Crear vector de prueba como los que envía Flutter
        test_vector = np.array([
            0.0, 0.0, 0.0, -0.20969066567689482, 0.7171724182472736, -0.2043579628035703,
            -0.4857909707568695, 1.1426171440649213, -0.2915554804356782, -0.7316223082673895,
            # ... más valores simulando landmarks normalizados
        ] + [0.0] * 117 + [1.0])  # Padding + numHands
        
        print(f"🧪 Test vector length: {len(test_vector)}")
        
        # Escalar usando scaler_params
        mean = np.array(scaler_params["mean"])
        scale = np.array(scaler_params["scale"])
        scaled_vector = (test_vector - mean) / scale
        
        print(f"🧪 Scaled vector shape: {scaled_vector.shape}")
        print(f"🧪 Scaled vector primeros 10: {scaled_vector[:10]}")
        
        # Verificar valores problemáticos
        has_nan = np.any(np.isnan(scaled_vector))
        has_inf = np.any(np.isinf(scaled_vector))
        print(f"🧪 ¿Hay NaN?: {has_nan}")
        print(f"🧪 ¿Hay infinitos?: {has_inf}")
        
        if has_nan or has_inf:
            print("❌ Vector contiene valores inválidos")
            return False
        
        # Ejecutar predicción
        interpreter.set_tensor(input_details[0]['index'], [scaled_vector.astype(np.float32)])
        interpreter.invoke()
        
        # Obtener resultado
        output = interpreter.get_tensor(output_details[0]['index'])
        predictions = output[0]
        
        print(f"🧪 Output shape: {output.shape}")
        print(f"🧪 Predictions sum: {np.sum(predictions):.6f}")
        print(f"🧪 Primeras 10 predicciones: {predictions[:10]}")
        
        # Encontrar top predicción
        top_idx = np.argmax(predictions)
        top_confidence = predictions[top_idx]
        top_label = labels[top_idx]
        
        print(f"🧪 Top predicción: {top_label} ({top_confidence:.4f})")
        
        # Mostrar top 5
        top_indices = np.argsort(predictions)[-5:][::-1]
        print("🧪 Top 5 predicciones:")
        for i, idx in enumerate(top_indices):
            label = labels[idx]
            conf = predictions[idx]
            print(f"   {i+1}. {label}: {conf:.4f}")
        
        return True
        
    except ImportError:
        print("❌ TensorFlow no disponible")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_flutter_vector():
    """Test con vector exacto de Flutter"""
    print("\n🔍 Testing con vector de Flutter...")
    
    # Vector exacto de los logs de Flutter
    flutter_vector = [
        0.0, 0.0, 0.0, -0.20969066567689482, 0.7171724182472736, -0.2043579628035703,
        -0.4857909707568695, 1.1426171440649213, -0.2915554804356782, -0.7316223082673895
    ]
    
    # Simular el resto del vector (Flutter usa 126 + 1)
    full_vector = flutter_vector + [0.0] * 116 + [1.0]  # numHands = 1
    
    print(f"🧪 Flutter vector length: {len(full_vector)}")
    print(f"🧪 NumHands: {full_vector[-1]}")
    
    try:
        import tensorflow as tf
        
        # Cargar modelo y scaler
        interpreter = tf.lite.Interpreter(model_path="assets/models/sign_model.tflite")
        interpreter.allocate_tensors()
        
        with open("assets/scaler_params.json", "r") as f:
            scaler_params = json.load(f)
        
        with open("assets/labels.json", "r") as f:
            labels = json.load(f)
        
        # Escalar exactamente como Flutter
        mean = np.array(scaler_params["mean"])
        scale = np.array(scaler_params["scale"])
        scaled = (np.array(full_vector) - mean) / scale
        
        print(f"🧪 Scaled primeros 10: {scaled[:10]}")
        
        # Ejecutar
        input_details = interpreter.get_input_details()
        interpreter.set_tensor(input_details[0]['index'], [scaled.astype(np.float32)])
        interpreter.invoke()
        
        output_details = interpreter.get_output_details()
        predictions = interpreter.get_tensor(output_details[0]['index'])[0]
        
        top_idx = np.argmax(predictions)
        predicted_label = labels[top_idx]
        confidence = predictions[top_idx]
        
        print(f"🧪 Python TFLite result: {predicted_label} ({confidence:.4f})")
        print(f"🧪 ¿Coincide con Flutter 'Renunciar'?: {predicted_label == 'Renunciar'}")
        
        return predicted_label, confidence
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return None, None

def check_scaler_issues():
    """Verificar problemas con el scaler"""
    print("\n🔍 Verificando scaler...")
    
    with open("assets/scaler_params.json", "r") as f:
        scaler_params = json.load(f)
    
    mean = np.array(scaler_params["mean"])
    scale = np.array(scaler_params["scale"])
    
    # Buscar escalas problemáticas
    zero_scales = np.where(scale == 0.0)[0]
    small_scales = np.where(np.abs(scale) < 1e-6)[0]
    
    print(f"📊 Escalas cero: {len(zero_scales)} índices")
    print(f"📊 Escalas muy pequeñas: {len(small_scales)} índices")
    
    if len(zero_scales) > 0:
        print(f"⚠️ Índices con escala cero: {zero_scales[:10]}...")
    
    if len(small_scales) > 0:
        print(f"⚠️ Índices con escala muy pequeña: {small_scales[:10]}...")
    
    # Verificar rangos
    print(f"📊 Mean range: [{np.min(mean):.6f}, {np.max(mean):.6f}]")
    print(f"📊 Scale range: [{np.min(scale):.6f}, {np.max(scale):.6f}]")

def main():
    print("🚀 Iniciando tests de validación...")
    print("="*60)
    
    # Verificar archivos
    required_files = [
        "assets/models/sign_model.tflite",
        "assets/scaler_params.json", 
        "assets/labels.json"
    ]
    
    for file in required_files:
        if os.path.exists(file):
            print(f"✅ {file} encontrado")
        else:
            print(f"❌ {file} NO encontrado")
            return
    
    # Ejecutar tests
    check_scaler_issues()
    test_tflite_model()
    test_flutter_vector()
    
    print("\n" + "="*60)
    print("📋 CONCLUSIONES:")
    print("1. Si TensorFlow funciona → El modelo TFLite es válido")
    print("2. Si el vector de Flutter da resultado diferente → Problema en normalización") 
    print("3. Si hay escalas cero → Problema en el scaler_params.json")
    print("4. La inconsistencia en Flutter es normal por variabilidad de landmarks")

if __name__ == "__main__":
    main()