#!/usr/bin/env python3
"""
Script para verificar los archivos de configuración
"""
import json
import os

def check_assets():
    """Verificar archivos en assets/"""
    print("🔍 Verificando archivos de configuración...")
    
    # Verificar labels.json
    labels_path = "assets/labels.json"
    if os.path.exists(labels_path):
        with open(labels_path, 'r') as f:
            labels = json.load(f)
        print(f"✅ labels.json: {len(labels)} etiquetas encontradas")
        print(f"   Primeras 5: {labels[:5]}")
        print(f"   Últimas 5: {labels[-5:]}")
    else:
        print(f"❌ {labels_path} no encontrado")
    
    # Verificar scaler_params.json
    scaler_path = "assets/scaler_params.json"
    if os.path.exists(scaler_path):
        with open(scaler_path, 'r') as f:
            scaler = json.load(f)
        print(f"✅ scaler_params.json encontrado")
        print(f"   Mean length: {len(scaler['mean'])}")
        print(f"   Scale length: {len(scaler['scale'])}")
        print(f"   Primeros 5 mean: {scaler['mean'][:5]}")
        print(f"   Primeros 5 scale: {scaler['scale'][:5]}")
        
        # Verificar que todos los valores de scale son > 0
        scale_values = scaler['scale']
        zero_scales = [i for i, val in enumerate(scale_values) if val <= 0]
        if zero_scales:
            print(f"⚠️ Escalas cero o negativas en índices: {zero_scales}")
        else:
            print(f"✅ Todas las escalas son positivas")
    else:
        print(f"❌ {scaler_path} no encontrado")
    
    # Verificar modelo TFLite
    model_path = "assets/models/sign_model.tflite"
    if os.path.exists(model_path):
        size = os.path.getsize(model_path)
        print(f"✅ sign_model.tflite encontrado ({size} bytes)")
    else:
        print(f"❌ {model_path} no encontrado")

def analyze_python_code():
    """Analizar el código Python para extraer información clave"""
    print("\n🔍 Analizando código Python...")
    
    notebook_path = "temporal/Training/Modelo.ipynb"
    if os.path.exists(notebook_path):
        print(f"✅ {notebook_path} encontrado")
        
        # Leer el notebook y buscar información clave
        with open(notebook_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Buscar información sobre el modelo
        if "input_dim" in content:
            print("✅ Modelo usa input_dim")
        
        if "num_hands" in content:
            print("✅ Código incluye num_hands")
        
        if "StandardScaler" in content:
            print("✅ Usa StandardScaler")
        
        if "hand_to_feature_vector" in content:
            print("✅ Función hand_to_feature_vector encontrada")
        
        if "coords[9]" in content:
            print("✅ Usa landmark 9 para normalización")
    else:
        print(f"❌ {notebook_path} no encontrado")

def compare_dimensions():
    """Comparar dimensiones esperadas"""
    print("\n🔍 Comparando dimensiones...")
    
    # Cargar archivos de configuración
    try:
        with open("assets/labels.json", 'r') as f:
            labels = json.load(f)
        
        with open("assets/scaler_params.json", 'r') as f:
            scaler = json.load(f)
        
        num_labels = len(labels)
        input_features = len(scaler['mean'])
        
        print(f"📊 Número de etiquetas: {num_labels}")
        print(f"📊 Features de entrada: {input_features}")
        
        # Verificar si las dimensiones son correctas
        expected_features = 126 + 1  # 2 manos * 21 landmarks * 3 coords + num_hands
        if input_features == expected_features:
            print(f"✅ Dimensiones correctas: 126 landmarks + 1 num_hands = {input_features}")
        else:
            print(f"⚠️ Dimensiones inesperadas. Esperado: {expected_features}, Actual: {input_features}")
        
        # Verificar consistencia
        if len(scaler['mean']) == len(scaler['scale']):
            print("✅ Dimensiones de mean y scale son consistentes")
        else:
            print("❌ Dimensiones de mean y scale no coinciden")
            
    except Exception as e:
        print(f"❌ Error al cargar archivos: {e}")

def main():
    print("🚀 Iniciando verificación de configuración...")
    check_assets()
    analyze_python_code()
    compare_dimensions()
    
    print("\n" + "="*50)
    print("📋 RESUMEN DE PROBLEMAS POTENCIALES:")
    print("1. ❌ Rotación de landmarks en Flutter (ELIMINADA)")
    print("2. ⚠️ Diferencias en normalización entre Python/Flutter")
    print("3. ⚠️ Verificar que el vector de entrada tenga exactamente 127 features")
    print("4. ⚠️ Verificar que la ordenación de manos sea igual")
    print("5. ⚠️ Verificar que el threshold de confianza sea apropiado")

if __name__ == "__main__":
    main()