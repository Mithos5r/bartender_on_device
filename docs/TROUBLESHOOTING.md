# Troubleshooting — Bartender On Device

Problemas conocidos, su causa y cómo resolverlos.

---

## 1. Tildes duplicadas / descolocadas al escribir (iOS con teclado físico)

**Síntoma**: al escribir con acentos sale algo como `m´ás` en vez de `más`. Lo mismo con diéresis (`ü`) y otras teclas muertas.

**Causa**: es un **bug del engine de Flutter en iOS**, no de esta app. El plugin de entrada de texto (`FlutterTextInputPlugin`) no reemplaza correctamente el rango "composing"/"marked" al insertar una tecla muerta con teclado hardware, así que el acento se duplica.

- Issue: [flutter/flutter#146486](https://github.com/flutter/flutter/issues/146486) (relacionado: [#59541](https://github.com/flutter/flutter/issues/59541))
- PR de arreglo (pendiente de aterrizar): [#191062](https://github.com/flutter/flutter/pull/191062) — _"\[iOS\] TextField should support typing accented words with external keyboard"_

Se reproduce en **cualquier** app Flutter con un `TextField` y teclado físico en iOS, no solo en esta.

**Workarounds mientras tanto:**
- **Simulador**: menú `I/O → Keyboard` y **desmarca** "Connect Hardware Keyboard". Usa el teclado en pantalla (táctil), que compone bien las tildes.
- **Dispositivo real**: evita teclado externo para texto con tildes; usa el teclado en pantalla.
- **Acción definitiva**: `flutter upgrade` cuando el PR se publique y verificar de nuevo.

**Decisión del proyecto**: no se aplica parche a nivel de app (un `TextInputFormatter` heurístico sería frágil y podría romper usos legítimos de `´`); se espera el fix upstream. Ver README → _Known limitations_.

---

## 2. La generación es lenta / se detecta backend CPU

**Síntoma**: la carga tarda 20–40 s y los logs muestran `bundle sampler: none` y/o que se usa CPU.

**Causa**: `PreferredBackend.gpu` es una **preferencia**, no una garantía. Si el dispositivo o el simulador no ofrecen aceleración compatible, el engine cae a CPU automáticamente.

**Qué hacer:**
- En simulador iOS, CPU es esperado.
- En dispositivo real, verifica que el modelo soporte el backend de GPU del equipo.
- La generación seguirá funcionando en CPU, solo más despacio.

---

## 3. Error de autorización al descargar el modelo

**Síntoma**: fallo de descarga con error de autorización/acceso.

**Causa**: algunos modelos de Hugging Face son **gated** (restringidos).

**Solución**: en la pantalla de setup, toca el icono de **llave** y pega un **token de acceso de Hugging Face**. Se usa solo para esa descarga.

---

## 4. "No se pudo cargar el modelo" tras la descarga

**Causas posibles**: descarga incompleta/corrupta o interrupción durante la carga.

**Solución**: usa el botón **Reintentar descarga** en la pantalla de setup (el estado pasa a `error` → reintenta). Si persiste, haz un clean install (sección 5).

---

## 5. Reset / clean install (desarrollo en macOS)

Si el sandbox de macOS o los datos derivados quedan en mal estado:

```bash
pkill -f "flutter.*run.*macos" || true
pkill -f "bartender_on_device" || true
DATA="$HOME/Library/Containers/es.cayetano.bartenderOnDevice"
[ -d "$DATA" ] && /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -u "$DATA" || true
rm -rf "$DATA"
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
cd "$HOME/Desktop/OwnerProjects/bartender_on_device"
flutter clean
rm -rf build/
```

Esto borra el contenedor de la app (incluido el modelo descargado), los datos derivados de Xcode y los artefactos de build.

---

## 6. Web: el modelo no genera

**Síntoma**: en web el engine se inicializa pero no produce texto.

**Causa**: el archivo nativo `gemma-4-E2B-it.litertlm` **no se ejecuta en el navegador**. Web requiere un export dedicado `-web.litertlm` del modelo.

**Estado**: el setup web (módulos `cache_api.js`, `opfs_helper.js`, `@litert-lm/core` en `web/index.html`) está cableado, pero la generación web necesita ese export web del modelo. Ver README → _Web note_.

---

## 7. Errores de build / versiones de SDK

- **Dart/Flutter**: las dependencias `flutter_edge_ai ^2.4.1` y `flutter_edge_ai_litertlm ^1.15.0` requieren Dart `>=3.12.0` y Flutter `>=3.44.0`. `pubspec.lock` puede exigir Flutter `>=3.47.0`. Si `flutter pub get` falla, ejecuta `flutter --version` y actualiza con `flutter upgrade`.
- **Android**: `minSdk = 30`, solo `arm64-v8a`.
- **iOS**: deployment target `16.0`.
- **macOS**: el `Podfile` incluye un `post_install` de LiteRT-LM y `Release.entitlements` necesita `com.apple.security.cs.disable-library-validation`.

Diagnóstico general:

```bash
flutter doctor -v
flutter clean && flutter pub get
```
