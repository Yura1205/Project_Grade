# 🔧 Troubleshooting Codemagic iOS Build

## 🚨 Problemas Comunes y Soluciones

### ❌ **Error: "CocoaPods not found"**
```yaml
# Solución en codemagic.yaml:
scripts:
  - name: Install CocoaPods
    script: |
      sudo gem install cocoapods
      find . -name "Podfile" -execdir pod install \;
```

### ❌ **Error: "Flutter packages failed"**
```yaml
# Solución:
scripts:
  - name: Clean and get packages
    script: |
      flutter clean
      flutter pub get
```

### ❌ **Error: "Xcode build failed"**
```yaml
# Solución:
environment:
  xcode: latest  # Usar Xcode más reciente
  flutter: stable
```

### ❌ **Error: "Bundle ID issues"**
Verificar en `ios/Runner.xcodeproj/project.pbxproj`:
```
PRODUCT_BUNDLE_IDENTIFIER = com.yura1205.signlanguagedetector;
```

### ❌ **Error: "Camera permission missing"**
Verificar en `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Esta app necesita acceso a la cámara para detectar señas</string>
<key>NSMicrophoneUsageDescription</key>
<string>Esta app usa el micrófono para text-to-speech</string>
```

## 📋 **Checklist de Configuración**

### ✅ **Antes del Build:**
- [ ] Archivo `codemagic.yaml` presente
- [ ] Branch `eriko_dev` pusheado
- [ ] Bundle ID configurado
- [ ] Permisos iOS configurados
- [ ] Dependencias actualizadas

### ✅ **Durante el Build:**
- [ ] Workflow seleccionado: `ios-workflow`
- [ ] Branch correcto: `eriko_dev`
- [ ] Instancia: `mac_mini_m1`
- [ ] Timeout suficiente: 60+ minutos

### ✅ **Después del Build:**
- [ ] Artifacts descargados
- [ ] Archivo .ipa válido
- [ ] Tamaño > 0 MB

## 🔍 **Cómo leer los logs:**

### **Build exitoso:**
```
✅ Get Flutter packages - SUCCESS
✅ Install iOS dependencies - SUCCESS  
✅ Flutter analyze - SUCCESS
✅ Build iOS - SUCCESS
✅ Create IPA - SUCCESS
```

### **Build fallido:**
```
❌ Step X failed with exit code Y
[Logs detallados del error]
```

## 📱 **Verificación del .ipa:**

```bash
# En tu PC, verificar el archivo:
file app.ipa
# Debería mostrar: "Zip archive data"

unzip -l app.ipa
# Debería mostrar estructura de app iOS
```

## 🆘 **Si todo falla:**

### **Plan B: Build local con herramientas**
```bash
# Alternativa: Usar GitHub Actions
# El archivo ya está en .github/workflows/ios-build.yml
```

### **Plan C: Build simplificado**
```yaml
# codemagic.yaml mínimo:
workflows:
  basic-ios:
    name: Basic iOS Build
    environment:
      flutter: stable
    scripts:
      - flutter pub get
      - flutter build ios --no-codesign
    artifacts:
      - build/ios/iphoneos/Runner.app
```

## 📞 **Información para soporte:**

Si necesitas ayuda, comparte:
1. **Logs completos** del build fallido
2. **Configuración** de codemagic.yaml
3. **Branch y commit** usado
4. **Mensaje de error** específico

---

**💡 Tip: La mayoría de errores son por dependencias iOS o configuración de Bundle ID**