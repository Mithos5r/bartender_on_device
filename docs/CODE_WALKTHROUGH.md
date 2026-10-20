# Recorrido del código — Bartender On Device

Guía **archivo por archivo** para entender (y poder explicar) cómo funciona cada pieza. Cada sección incluye: **qué hace**, el **fragmento clave** y el **por qué** de las decisiones no obvias.

> Para la visión de conjunto y los diagramas, ver [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Índice

1. [Punto de entrada — `main.dart`](#1-punto-de-entrada--maindart)
2. [Aplicación — `app/app.dart`](#2-aplicación--appappdart)
3. [Tema — `app/theme.dart`](#3-tema--appthemedart)
4. [Servicio del modelo — `core/model/model_service.dart`](#4-servicio-del-modelo--coremodelmodel_servicedart)
5. [Config del modelo — `core/model/model_config.dart`](#5-config-del-modelo--coremodelmodel_configdart)
6. [System prompt — `core/persona/cocktail_system_prompt.dart`](#6-system-prompt--corepersonacocktail_system_promptdart)
7. [Persistencia — `core/storage/chat_storage.dart`](#7-persistencia--corestoragechat_storagedart)
8. [Modelo de mensaje — `features/chat/models/chat_message.dart`](#8-modelo-de-mensaje--featureschatmodelschat_messagedart)
9. [Controlador — `features/chat/models/chat_controller.dart`](#9-controlador--featureschatmodelschat_controllerdart)
10. [Pantalla de chat — `features/chat/ui/chat_screen.dart`](#10-pantalla-de-chat--featureschatuichat_screendart)
11. [Pantalla de setup — `features/chat/ui/setup_screen.dart`](#11-pantalla-de-setup--featureschatuisetup_screendart)
12. [Widgets](#12-widgets)
13. [Glosario de la API `flutter_edge_ai`](#13-glosario-de-la-api-flutter_edge_ai)
14. [Tests](#14-tests)

---

## 1. Punto de entrada — `main.dart`

**Qué hace**: inicializa el motor de inferencia y arranca la app.

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FlutterEdgeAi.initialize(
    maxDownloadRetries: 5,
    inferenceEngines: const [LiteRtLmEngine()],
    webStorageMode: WebStorageMode.streaming,
  );

  runApp(const BartenderApp());
}
```

**Por qué cada línea:**
- `WidgetsFlutterBinding.ensureInitialized()` → obligatorio antes de usar plugins (aquí, canales nativos) en `main`, antes de `runApp`.
- `inferenceEngines: [LiteRtLmEngine()]` → registra el backend concreto (LiteRT LM). Es lo que permite luego `installModel`/`getActiveModel`.
- `maxDownloadRetries: 5` → reintenta la descarga del modelo (red móvil, cortes).
- `webStorageMode: WebStorageMode.streaming` → en web no carga el modelo entero en memoria; lo hace en streaming.

---

## 2. Aplicación — `app/app.dart`

**Qué hace**: define el `MaterialApp` y decide la pantalla inicial.

```dart
MaterialApp(
  title: 'Bartender On Device',
  theme: AppTheme.dark(),
  darkTheme: AppTheme.dark(),
  themeMode: ThemeMode.dark,
  home: const _Bootstrap(),
)
```

`_Bootstrap` es un `StatefulWidget` que en `initState` comprueba si el modelo está instalado y elige pantalla:

```dart
final installed = await ModelService.instance.isModelInstalled();
setState(() {
  _initialScreen = installed ? const ChatScreen() : const SetupScreen();
});
```

- Mientras se decide, muestra un `CircularProgressIndicator`.
- Si la comprobación lanza excepción, cae a `SetupScreen` (fail-safe: mejor ofrecer descargar que quedarse bloqueado).
- **Por qué el disco es la fuente de verdad**: no se guarda un flag "ya configurado"; si el archivo del modelo existe, está listo. Evita estados inconsistentes.

---

## 3. Tema — `app/theme.dart`

**Qué hace**: tema Material 3 en modo oscuro con un color semilla cobre (ambiente de bar).

```dart
static const Color _seed = Color(0xFFB87333); // cobre

ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark);
```

- `ColorScheme.fromSeed` genera toda la paleta (primario, superficies, contenedores) a partir de un color.
- `scaffoldBackgroundColor: Color(0xFF14110F)` y `AppBar` en `0xFF1B1714` → tonos cálidos oscuros de madera/cuero.
- `inputDecorationTheme` global → todos los `TextField` comparten estilo redondeado sin borde.
- La app fuerza `themeMode: ThemeMode.dark` (aunque define `theme` y `darkTheme`, ambos oscuros).

---

## 4. Servicio del modelo — `core/model/model_service.dart`

**Qué hace**: encapsula todo el trato con el modelo. Es un **singleton** y es **agnóstico del modelo** (todo lo concreto sale de `config`).

```dart
class ModelService {
  ModelService._();                                  // constructor privado
  static final ModelService instance = ModelService._();

  ModelConfig config = kDefaultModel;                // por defecto: GemmaModel
  InferenceModel? _model;
  InferenceChat? _chat;
```

**Descarga** (builder fluido de la API, leyendo del `config`):

```dart
await FlutterEdgeAi.installModel(
      modelType: config.modelType,
      fileType: config.fileType,
    )
    .fromNetwork(config.url, token: huggingFaceToken)
    .withProgress(onProgress)
    .install();
```

- `.withProgress(onProgress)` reporta 0–100 para la barra de progreso.
- `token` es opcional (solo modelos restringidos de Hugging Face).

**Carga + chat**:

```dart
_model = await FlutterEdgeAi.getActiveModel(
  maxTokens: config.contextTokens,
  preferredBackend: preferredBackend ?? config.preferredBackend,
);

_chat = await _model!.createChat(
  systemInstruction: systemInstruction,   // lo pasa el llamador (persona de la app)
  modelType: config.modelType,
  maxOutputTokens: config.maxOutputTokens,
  topK: config.topK,
);
```

- `preferredBackend` → intenta GPU; el engine hace fallback a CPU si no hay aceleración (ver TROUBLESHOOTING).
- `systemInstruction` → la persona/reglas las recibe **como parámetro**, porque son del dominio de la app, no del modelo. Los llamadores (`ChatController`, `SetupScreen`) pasan `cocktailSystemPrompt`.
- `topK: 1` → decodificación *greedy* (determinista).
- `maxOutputTokens` → acota la respuesta.

**Streaming de tokens**:

```dart
Stream<String> sendMessageStream(InferenceChat chat, String text) async* {
  await chat.addQueryChunk(Message.text(text: text, isUser: true));
  await for (final response in chat.generateChatResponseAsync()) {
    if (response is TextResponse) {
      yield response.token;
    }
  }
}
```

- `async*` convierte el flujo de eventos del engine en un `Stream<String>` sencillo.
- Se filtran solo los `TextResponse` (el engine puede emitir otros tipos de evento); de cada uno se emite su `.token`.

**Ciclo de vida**: `cancel()` → `stopGeneration()`; `resetChat()` → cierra el `InferenceChat`; `dispose()` → cierra chat y modelo y los pone a `null`. El flag `hasModel` evita recargar el modelo si ya está en memoria.

---

## 5. Config del modelo — `core/model/model_config.dart`

**Qué hace**: describe todo lo específico de un modelo en una jerarquía **sellada**. Cambiar de modelo = escribir una subclase o asignar otra config al servicio.

```dart
sealed class ModelConfig {
  const ModelConfig();
  String get fileName;
  String get url;
  ModelType get modelType;
  ModelFileType get fileType;
  int get contextTokens;
  int get maxOutputTokens;
  int get topK;
  PreferredBackend get preferredBackend;
  double get sizeBytes;
  String get displayName;
  String get sizeLabel;
}

final class GemmaModel extends ModelConfig {
  const GemmaModel();
  @override String get fileName => 'gemma-4-E2B-it.litertlm';
  @override ModelType get modelType => ModelType.gemma4;
  // …resto de getters
}

const ModelConfig kDefaultModel = GemmaModel();
```

- `sealed` restringe la jerarquía a las subclases declaradas en el mismo archivo, lo que permite un `switch` exhaustivo si en el futuro hay comportamiento por modelo.
- `fileName` se usa tanto para descargar como para `isModelInstalled`.
- `contextTokens` es el tamaño de la ventana de contexto; `maxOutputTokens` el tope por turno; `topK`/`preferredBackend` son parámetros de inferencia.
- `displayName` / `sizeLabel` son para la UI; `sizeBytes` para comprobaciones de espacio.
- `kDefaultModel` es el modelo que arranca la app, inyectado en `ModelService`.

**Por qué `sealed`**: aísla lo específico del modelo en un único punto y ofrece exhaustividad de tipos. Añadir un modelo nuevo = crear otra `final class` (e.g. `GemmaVariant`) sin tocar el servicio ni la UI.

---

## 6. System prompt — `core/persona/cocktail_system_prompt.dart`

**Qué hace**: una única constante `cocktailSystemPrompt` con las instrucciones fijas del modelo. Vive en `core/persona/` porque es la **persona de la app**, no algo del modelo.

Contiene cuatro bloques:
1. **Persona**: "Bartender On Device", 20+ años de experiencia, tono cercano, responde en español.
2. **Conocimiento**: cócteles, técnicas, ingredientes, historia, sustituciones, maridaje, mocktails.
3. **Formato de receta**: nombre, tipo, cristalería, técnica, ingredientes, preparación, garnish, dato curioso.
4. **Límites de tema (estricto)**: si la pregunta está fuera de coctelería, responde con una sola frase amable y redirige. Además, reglas numeradas (no inventar marcas, ser honesto si no está seguro, etiquetar variantes, no dar consejos médicos, verificar normativa local, ser conciso 80–200 palabras, sin emojis).

**Por qué importa**: el comportamiento "solo bar" de la app **no está en el código Dart**; está aquí. Si quieres cambiar la personalidad o el formato, este es el archivo. Se inyecta en `ModelService.createChat(systemInstruction: cocktailSystemPrompt)`.

---

## 7. Persistencia — `core/storage/chat_storage.dart`

**Qué hace**: guarda/lee/borra el historial en `shared_preferences` como una cadena JSON.

```dart
static const String _kHistoryKey = 'chat_history_v1';

Future<List<ChatMessage>> loadHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_kHistoryKey);
  if (raw == null || raw.isEmpty) return [];
  return chatMessagesFromJson(raw);
}
```

- Singleton igual que `ModelService` (`ChatStorage.instance`).
- Clave versionada (`_v1`) para poder migrar el formato en el futuro.
- Lee/escribe a través de `chat_message.dart` (no conoce el formato JSON en detalle).

---

## 8. Modelo de mensaje — `features/chat/models/chat_message.dart`

**Qué hace**: representa un mensaje y su (de)serialización.

```dart
enum MessageRole { user, assistant }
enum MessageStatus { sending, streaming, done, error }

class ChatMessage {
  final MessageRole role;
  String text;                 // mutable: crece token a token
  final DateTime timestamp;
  MessageStatus status;        // mutable: cambia con el streaming
}
```

- `text` y `status` son `var` porque el mensaje del asistente se construye incrementalmente.
- `toJson`/`fromJson` con `orElse` defensivo: si el JSON guardado está corrupto o desactualizado, se cae a `user` / `done` en vez de lanzar (la app nunca crashea por historial inválido).
- `chatMessagesToJson` / `chatMessagesFromJson` son funciones top-level que envuelven la lista.

---

## 9. Controlador — `features/chat/models/chat_controller.dart`

**Qué hace**: es el **cerebro del estado del chat**. Extiende `ChangeNotifier`, así que la UI se suscribe con `addListener`.

```dart
enum ChatPhase { uninitialized, ready, generating, error }

class ChatController extends ChangeNotifier {
  ChatController({ModelService? service, ChatStorage? storage})
    : _service = service ?? ModelService.instance,
      _storage = storage ?? ChatStorage.instance;
```

- **Inyección de dependencias opcional**: en los tests se pueden pasar dobles en vez de los singletons.

**`initialize()`** (al montar `ChatScreen`):
1. Carga el historial guardado (`_storage.loadHistory()`).
2. Si no hay modelo en memoria, lo carga; si no hay chat, lo crea.
3. Pasa a `ready`.

**`sendMessage(text)`** — el núcleo:
```dart
_messages.add(userMessage);
final assistantMessage = ChatMessage(role: assistant, text: '', status: streaming);
_messages.add(assistantMessage);
_phase = ChatPhase.generating;
await _persist();

await for (final token in _service.sendMessageStream(chat, trimmed)) {
  assistantMessage.text += token;
  notifyListeners();          // repinta la burbuja en cada token
}
assistantMessage.status = done;
_phase = ChatPhase.ready;
await _persist();
```
- Se crea la burbuja del asistente **vacía** y se rellena token a token.
- En error: si no llegó ningún token, se muestra `Error: …` dentro de la burbuja; si llegó algo, se conserva lo recibido y se marca `error`.

**`cancel()`**: detiene la generación y marca el último mensaje del asistente como `done`.

**`clearHistory()`**: vacía la lista, borra el almacenamiento y recrea el chat (contexto limpio).

**`_persist()`**:
```dart
final persistable = _messages.where((m) => m.status != MessageStatus.streaming).toList();
await _storage.saveHistory(persistable);
```
- Solo guarda mensajes no-streaming, para no persistir burbujas a medio construir.

**`dispose()`**: llama a `_service.dispose()` (con `unawaited`) para liberar el modelo.

---

## 10. Pantalla de chat — `features/chat/ui/chat_screen.dart`

**Qué hace**: la pantalla principal. Contiene el `ChatController` y el `ScrollController`.

- Escucha al controlador y hace `setState` + autoscroll en un `addPostFrameCallback` (no se puede scrollear hasta que el frame se ha pintado).
- `ListView.builder` añade un elemento extra (`TypingIndicator`) cuando `isGenerating`.
- `AppBar` con acción "Borrar conversación" que abre un `AlertDialog` de confirmación.
- Banner de error (`_ErrorBanner`) arriba cuando `errorMessage != null`.
- Cuando no hay mensajes, muestra `EmptyState` (con sugerencias clickeables que llaman a `sendMessage`).

**Por qué `MessageBubble` recibe el objeto mutable**: la misma instancia de `ChatMessage` se va mutando durante el streaming; al reconstruir, la burbuja ya refleja el texto actual.

---

## 11. Pantalla de setup — `features/chat/ui/setup_screen.dart`

**Qué hace**: primera ejecución. Gestiona descarga, carga y token de Hugging Face.

- Estado local: `_status` (`SetupStatus`), `_progress`, `_errorMessage`, `_huggingFaceToken`.
- `_checkStatus()`: si el modelo ya está, salta directo a cargar; si no, deja el botón de descarga.
- `_startDownload()`: llama a `ModelService.instance.downloadModel(...)` pasando `onProgress` (actualiza la barra) y el token opcional.
- `_loadModel()`: carga el modelo, crea el chat y navega al chat.
- Manejo de error específico:
  ```dart
  } on DownloadException catch (e) {
    _errorMessage = e.error.toUserMessage();   // mensaje legible para el usuario
  } catch (e) {
    _errorMessage = e.toString();
  }
  ```
- `_editToken()`: diálogo para introducir/cambiar el token (`obscureText: true`).
- Guardas `if (!mounted) return;` tras cada `await` — patrón obligatorio antes de `setState` para evitar usar un widget ya desmontado.

---

## 12. Widgets

Todos en `features/chat/ui/widgets/`.

### `input_bar.dart`
- `StatefulWidget` con su propio `TextEditingController` y `FocusNode`.
- Escucha el controlador para habilitar/deshabilitar el botón de enviar (`_canSend` = texto no vacío).
- `multiline` (`minLines: 1`, `maxLines: 4`) + `textInputAction: TextInputAction.send`.
- Un solo `IconButton` que cambia entre **enviar** y **detener** según `isGenerating`.

### `message_bubble.dart`
- Renderiza el mensaje con `MarkdownBody` (de `flutter_markdown_plus`), con un `MarkdownStyleSheet` a medida que respeta el color de texto según rol (usuario/assistant).
- Burbuja alineada a la derecha (usuario) o izquierda (asistente), con esquinas asimétricas.
- Si el texto está vacío y en streaming, muestra `…`.
- Si `message.isError`, muestra un encabezado "Error".
- `onTapLink` → `launchUrl` para abrir enlaces.

### `empty_state.dart`
- Estado inicial: icono, título, subtítulo y 4 sugerencias (`_suggestions`) que llaman a `onSuggestionTap`.
- **Por qué sugerencias**: dan al usuario pistas de que la app está limitada a cócteles.

### `typing_indicator.dart`
- Tres puntos que escalan con un `AnimationController` en bucle.
- Se muestra mientras `isGenerating` y aún no hay texto.

### `model_status_card.dart`
- Define el `enum SetupStatus { idle, checking, downloading, loading, ready, error }`.
- Tarjeta que cambia icono/título/subtítulo según el estado, muestra barra de progreso mientras descarga, el bloque de carga (`_LoadingBlock`) y el mensaje de error.
- `_LoadingBlock` es un widget aparte con `Stopwatch` + `Timer` que muestra "Llevas Xs cargando" (feedback durante los 20–40 s de carga).

---

## 13. Glosario de la API `flutter_edge_ai`

| Símbolo | Qué es |
| --- | --- |
| `FlutterEdgeAi.initialize` | Arranca el plugin y registra los engines de inferencia |
| `FlutterEdgeAi.isModelInstalled(name)` | ¿Existe el archivo del modelo en disco? |
| `FlutterEdgeAi.installModel(...)` | Builder de descarga (`fromNetwork`, `withProgress`, `install`) |
| `FlutterEdgeAi.getActiveModel(...)` | Carga el modelo en memoria y devuelve `InferenceModel` |
| `ModelFileType.litertlm` | Tipo de archivo del modelo (LiteRT LM) |
| `ModelType.gemma4` | Identifica la familia Gemma 4 |
| `PreferredBackend.gpu` | Pista de backend (con fallback a CPU) |
| `WebStorageMode.streaming` | Modo de almacenamiento en web |
| `InferenceModel` | Modelo cargado; `createChat()` produce un `InferenceChat` |
| `InferenceChat` | Sesión de conversación con contexto |
| `Message.text(text:, isUser:)` | Mensaje de entrada al chat |
| `TextResponse` | Evento de streaming con un `.token` |
| `DownloadException` | Error de descarga; `e.error.toUserMessage()` da texto legible |

---

## 14. Tests

`test/widget_test.dart` prueba la serialización de `ChatMessage`:

```dart
test('ChatMessage roundtrips through JSON', () {
  final original = ChatMessage(role: MessageRole.user, text: 'Recomiéndame un cóctel', ...);
  final restored = chatMessagesFromJson(chatMessagesToJson([original]));
  expect(restored.first.text, 'Recomiéndame un cóctel');
  expect(restored.first.timestamp, original.timestamp);
});
```

- Verifica el **round-trip** (objeto → JSON → objeto) y que un JSON vacío/`null`/`{}` devuelve lista vacía.
- Estos tests no tocan el modelo ni la red: son puros y rápidos.

**Comandos:**
```bash
flutter analyze   # análisis estático
flutter test      # tests unitarios
```
