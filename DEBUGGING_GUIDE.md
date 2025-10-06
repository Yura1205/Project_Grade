# 🔧 Guía de Debugging para la Aplicación Flutter de Señas

## ✅ Cambios Implementados

### 1. **Eliminación de Rotación de Landmarks**
- ❌ **ANTES**: Se aplicaba rotación a los landmarks basada en la orientación de la cámara
- ✅ **DESPUÉS**: Se eliminó la rotación para que coincida exactamente con el código Python

### 2. **Normalización Mejorada**
- ✅ Normalización de landmarks exactamente igual que en Python
- ✅ Verificación de que cada mano tenga exactamente 21 landmarks
- ✅ Manejo de errores para landmarks inválidos

### 3. **Debugging Añadido**
- ✅ Logs detallados en `prediction_service.dart`
- ✅ Logs de información del vector en `camera_page.dart`
- ✅ Verificación de dimensiones del vector de entrada

### 4. **Threshold de Confianza Reducido**
- ❌ **ANTES**: 0.8 (muy alto para testing)
- ✅ **DESPUÉS**: 0.5 (mejor para debugging)

## 🚀 Cómo Ejecutar y Debuggear

### 1. **Ejecutar la Aplicación**
```bash
cd "/c/ERIKO/GIT CLONES/Project_Grade"
flutter run
```

### 2. **Revisar Logs en Tiempo Real**
Después de ejecutar, verifica los logs en la consola:
- `🔍 Input vector length: X` - Debe ser 126
- `🔍 Num hands detected: X` - 1 o 2
- `🔍 Predicted: LABEL with confidence: X.XXX`

### 3. **Problemas Comunes y Soluciones**

#### 🔴 **Error: "Tamaño de entrada inválido"**
- **Causa**: El vector no tiene 127 elementos (126 landmarks + 1 numHands)
- **Solución**: Verificar que cada mano detectada genere exactamente 63 features (21 landmarks × 3 coordenadas)

#### 🔴 **Confianza Muy Baja (<0.3)**
- **Causa**: Landmarks mal normalizados o manos mal detectadas
- **Solución**: Verificar logs de normalización y posicionamiento de manos

#### 🔴 **Detección Inconsistente**
- **Causa**: Ordenamiento diferente de manos entre Python y Flutter
- **Solución**: Asegurar que las manos se ordenen por posición X (izquierda a derecha)

### 4. **Verificación de Archivos**
```bash
# Verificar que los archivos de configuración estén correctos
python check_config.py
```

## 📊 Comparación Python vs Flutter

| Aspecto | Python | Flutter | ✅/❌ |
|---------|---------|---------|-------|
| Normalización landmarks | `hand_to_feature_vector()` | `normalizeLandmarks()` | ✅ |
| Rotación de coordenadas | NO | ~~SÍ~~ NO | ✅ |
| Escalado con StandardScaler | `scaler.transform()` | Manual con mean/scale | ✅ |
| Ordenamiento de manos | Por centroide X | Por centroide X | ✅ |
| Input shape | [1, 127] | [1, 127] | ✅ |
| Output shape | [1, 82] | [1, 82] | ✅ |

## 🎯 Próximos Pasos si Sigue Fallando

1. **Verificar Calidad de Landmarks**
   - Asegurar buena iluminación
   - Manos completamente visibles
   - Sin oclusiones

2. **Ajustar Threshold**
   - Empezar con 0.3 para ver qué detecta
   - Gradualmente subir a 0.5, 0.7, 0.8

3. **Comparar Datos Directamente**
   - Imprimir vectores de entrada en ambos sistemas
   - Verificar que sean idénticos

4. **Verificar Ordenamiento**
   - Asegurar que el orden de las manos sea consistente
   - El código actual ordena por posición X (izquierda a derecha)

## 🔍 Debug Commands

```bash
# Ver logs de Flutter
flutter logs

# Compilar y ejecutar con verbose
flutter run -v

# Limpiar caché si hay problemas
flutter clean
flutter pub get
```

## 📱 Testing en Dispositivo

1. **Buena Iluminación**: Asegurar iluminación uniforme
2. **Fondo Contrastante**: Usar fondo simple, preferiblemente oscuro
3. **Distancia Apropiada**: Manos a distancia media de la cámara
4. **Movimientos Lentos**: Evitar movimientos rápidos durante testing

El modelo debería funcionar ahora mucho mejor. ¡Las diferencias principales han sido corregidas!