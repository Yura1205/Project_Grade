#!/usr/bin/env python3
"""
Script para generar landmarks de gestos específicos y compararlos con Flutter.
Ejecutar este script, mostrar los gestos A, Q, V, K y comparar con logs de Flutter.
"""

import cv2
import mediapipe as mp
import numpy as np
import json
import pickle

def load_model_components():
    """Cargar scaler y encoder del modelo Python"""
    try:
        with open('temporal/Training/scaler.pkl', 'rb') as f:
            scaler = pickle.load(f)
        with open('temporal/Training/label_encoder.pkl', 'rb') as f:
            label_encoder = pickle.load(f)
        return scaler, label_encoder
    except Exception as e:
        print(f"❌ Error cargando componentes: {e}")
        return None, None

def extract_landmarks(results):
    """Extraer landmarks igual que en Flutter"""
    if not results.multi_hand_landmarks:
        return None
    
    # Array para almacenar todas las features
    features = []
    
    # Procesar hasta 2 manos
    num_hands = min(len(results.multi_hand_landmarks), 2)
    print(f"🖐️ Detectadas {num_hands} mano(s)")
    
    for hand_idx, hand_landmarks in enumerate(results.multi_hand_landmarks[:2]):
        print(f"📍 Procesando mano {hand_idx}...")
        
        # Extraer landmarks (21 puntos × 3 coordenadas)
        landmarks = []
        for lm in hand_landmarks.landmark:
            landmarks.append([lm.x, lm.y, lm.z])
        
        # Mostrar landmarks RAW igual que en Flutter
        print("📍 Landmarks RAW (primeros 5):")
        for i in range(5):
            lm = landmarks[i]
            print(f"📍   [{i}]: ({lm[0]:.6f}, {lm[1]:.6f}, {lm[2]:.6f})")
        
        print("📍 Landmarks clave:")
        print(f"📍   Wrist[0]: ({landmarks[0][0]:.6f}, {landmarks[0][1]:.6f}, {landmarks[0][2]:.6f})")
        print(f"📍   Thumb[4]: ({landmarks[4][0]:.6f}, {landmarks[4][1]:.6f}, {landmarks[4][2]:.6f})")
        print(f"📍   Index[8]: ({landmarks[8][0]:.6f}, {landmarks[8][1]:.6f}, {landmarks[8][2]:.6f})")
        print(f"📍   Middle[12]: ({landmarks[12][0]:.6f}, {landmarks[12][1]:.6f}, {landmarks[12][2]:.6f})")
        
        # Aplanar landmarks
        flat_landmarks = np.array(landmarks).flatten()
        features.extend(flat_landmarks)
    
    # Completar con ceros si hay menos de 2 manos
    while len(features) < 126:  # 2 manos × 21 landmarks × 3 coords = 126
        features.append(0.0)
    
    # Agregar número de manos detectadas
    features.append(float(num_hands))
    
    print(f"📊 Vector completo: {len(features)} features")
    print(f"📊 Primeras 10 features: {features[:10]}")
    print(f"📊 Últimas 5 features: {features[-5:]}")
    
    return np.array(features)

def main():
    print("🎯 Iniciando comparación de landmarks...")
    
    # Cargar componentes del modelo
    scaler, label_encoder = load_model_components()
    if scaler is None:
        print("❌ No se pudieron cargar los componentes del modelo")
        return
    
    # Configurar MediaPipe igual que en Flutter
    mp_hands = mp.solutions.hands
    hands = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=2,
        min_detection_confidence=0.7,
        min_tracking_confidence=0.5
    )
    
    # Capturar desde cámara
    cap = cv2.VideoCapture(0)
    
    print("\n" + "="*60)
    print("🎯 INSTRUCCIONES:")
    print("1. Muestra los gestos A, Q, V, K")
    print("2. Presiona SPACE para capturar landmark")
    print("3. Presiona ESC para salir")
    print("4. Compara los landmarks con los logs de Flutter")
    print("="*60 + "\n")
    
    gesture_name = input("¿Qué gesto vas a mostrar? (A/Q/V/K): ").upper()
    
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        
        # Convertir a RGB
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Procesar con MediaPipe
        results = hands.process(rgb_frame)
        
        # Mostrar frame
        cv2.imshow('Landmarks Comparison - Press SPACE to capture', frame)
        
        key = cv2.waitKey(1) & 0xFF
        if key == 27:  # ESC
            break
        elif key == 32:  # SPACE
            print(f"\n🎯 CAPTURANDO GESTO '{gesture_name}':")
            print("="*50)
            
            features = extract_landmarks(results)
            if features is not None:
                print(f"\n📊 Vector final para comparar con Flutter:")
                print(f"📊 Tamaño: {len(features)}")
                print(f"📊 Primeras 10: {features[:10].tolist()}")
                print(f"📊 Features 60-70: {features[60:70].tolist()}")
                print(f"📊 Últimas 5: {features[-5:].tolist()}")
                
                # Normalizar con scaler
                normalized = scaler.transform([features])
                print(f"\n🔧 Vector normalizado:")
                print(f"🔧 Primeras 10: {normalized[0][:10].tolist()}")
                print(f"🔧 Últimas 5: {normalized[0][-5:].tolist()}")
                
                print("\n" + "="*50)
                print("👆 COPIA ESTOS VALORES Y COMPÁRALOS CON FLUTTER")
                print("="*50)
                
                # Pedir siguiente gesto
                gesture_name = input("\n¿Siguiente gesto? (A/Q/V/K o Enter para salir): ").upper()
                if not gesture_name:
                    break
            else:
                print("❌ No se detectaron manos")
    
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()