#!/usr/bin/env python3
"""
Script para debuggear y comparar el modelo Python vs TFLite
"""
import numpy as np
import tensorflow as tf
import json
import joblib

def load_python_model():
    """Cargar modelo Python original"""
    try:
        model = tf.keras.models.load_model("temporal/Training/best_model.keras")
        scaler = joblib.load("temporal/Training/scaler.pkl")
        label_encoder = joblib.load("temporal/Training/label_encoder.pkl")
        return model, scaler, label_encoder
    except Exception as e:
        print(f"❌ Error loading Python model: {e}")
        return None, None, None

def load_tflite_model():
    """Cargar modelo TFLite"""
    try:
        interpreter = tf.lite.Interpreter(model_path="assets/models/sign_model.tflite")
        interpreter.allocate_tensors()
        
        # Cargar scaler params y labels
        with open("assets/scaler_params.json", "r") as f:
            scaler_params = json.load(f)
        
        with open("assets/labels.json", "r") as f:
            labels = json.load(f)
            
        return interpreter, scaler_params, labels
    except Exception as e:
        print(f"❌ Error loading TFLite model: {e}")
        return None, None, None

def create_test_vector():
    """Crear vector de prueba simulando landmarks normalizados"""
    # Crear 126 features (2 manos * 21 landmarks * 3 coords)
    features = np.random.randn(126).astype(np.float32)
    num_hands = 2
    
    # Combinar features + num_hands
    test_vector = np.append(features, num_hands)
    return test_vector

def test_python_model(model, scaler, label_encoder, test_vector):
    """Probar modelo Python"""
    try:
        # Escalar
        scaled = scaler.transform([test_vector])
        
        # Predecir
        pred = model.predict(scaled, verbose=0)
        pred_idx = np.argmax(pred)
        pred_label = label_encoder.inverse_transform([pred_idx])[0]
        confidence = float(np.max(pred))
        
        print(f"🐍 Python - Predicted: {pred_label} (confidence: {confidence:.3f})")
        print(f"🐍 Python - Prediction shape: {pred.shape}")
        print(f"🐍 Python - Input shape: {scaled.shape}")
        
        return pred_label, confidence, pred
        
    except Exception as e:
        print(f"❌ Python model error: {e}")
        return None, None, None

def test_tflite_model(interpreter, scaler_params, labels, test_vector):
    """Probar modelo TFLite"""
    try:
        # Escalar manualmente
        mean = np.array(scaler_params["mean"])
        scale = np.array(scaler_params["scale"])
        scaled = (test_vector - mean) / scale
        
        # Configurar input
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        interpreter.set_tensor(input_details[0]['index'], [scaled.astype(np.float32)])
        interpreter.invoke()
        
        # Obtener output
        output = interpreter.get_tensor(output_details[0]['index'])
        pred_idx = np.argmax(output)
        pred_label = labels[pred_idx]
        confidence = float(np.max(output))
        
        print(f"📱 TFLite - Predicted: {pred_label} (confidence: {confidence:.3f})")
        print(f"📱 TFLite - Prediction shape: {output.shape}")
        print(f"📱 TFLite - Input shape: {input_details[0]['shape']}")
        
        return pred_label, confidence, output
        
    except Exception as e:
        print(f"❌ TFLite model error: {e}")
        return None, None, None

def compare_models():
    """Comparar ambos modelos"""
    print("🔍 Cargando modelos...")
    
    # Cargar modelos
    py_model, py_scaler, py_encoder = load_python_model()
    tflite_interpreter, scaler_params, labels = load_tflite_model()
    
    if None in [py_model, py_scaler, py_encoder]:
        print("❌ No se pudo cargar el modelo Python")
        return
        
    if None in [tflite_interpreter, scaler_params, labels]:
        print("❌ No se pudo cargar el modelo TFLite")
        return
    
    print("✅ Modelos cargados correctamente")
    
    # Crear vector de prueba
    test_vector = create_test_vector()
    print(f"🧪 Vector de prueba: shape={test_vector.shape}")
    print(f"🧪 Primeros 10 valores: {test_vector[:10]}")
    
    # Probar ambos modelos
    print("\n" + "="*50)
    py_label, py_conf, py_pred = test_python_model(py_model, py_scaler, py_encoder, test_vector)
    
    print("\n" + "="*50)
    tflite_label, tflite_conf, tflite_pred = test_tflite_model(tflite_interpreter, scaler_params, labels, test_vector)
    
    # Comparar resultados
    print("\n" + "="*50)
    print("📊 COMPARACIÓN:")
    print(f"Python:  {py_label} ({py_conf:.3f})")
    print(f"TFLite:  {tflite_label} ({tflite_conf:.3f})")
    
    if py_pred is not None and tflite_pred is not None:
        diff = np.abs(py_pred.flatten() - tflite_pred.flatten())
        max_diff = np.max(diff)
        mean_diff = np.mean(diff)
        print(f"Diferencia máxima: {max_diff:.6f}")
        print(f"Diferencia promedio: {mean_diff:.6f}")
        
        if max_diff < 1e-5:
            print("✅ Los modelos son prácticamente idénticos")
        elif max_diff < 1e-3:
            print("⚠️ Los modelos tienen pequeñas diferencias")
        else:
            print("❌ Los modelos tienen diferencias significativas")

if __name__ == "__main__":
    compare_models()