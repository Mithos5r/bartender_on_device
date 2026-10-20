# Bartender On Device

An on-device, AI-powered cocktail assistant built with Flutter. The app runs Google's **Gemma 4 (E2B)** model locally on the user's device via `flutter_edge_ai` + LiteRT LM — no cloud, no API keys, no data leaves the phone. Ask for classic recipes, modern twists, mocktails, ingredient substitutions, bar techniques, or food pairings, and get a streaming response from a virtual bartender with 20+ years of virtual experience.

> Project folder: `bartender_on_device`
> Internal app name (bundle id / package): `es.cayetano.bartenderOnDevice`

---

## Highlights

- **100% on-device inference** powered by `flutter_edge_ai` and the LiteRT LM engine (`flutter_edge_ai_litertlm`).
- **First-run setup flow** that downloads the Gemma 4 E2B model (≈ 2.59 GB) directly from Hugging Face, with progress reporting and optional token support.
- **Chat interface** with streaming responses, token-by-token typing indicator, and an empty state for new conversations.
- **Persistent chat history** stored locally with `shared_preferences` (reloaded on launch).
- **Light/dark themed** Material 3 UI (`AppTheme.dark()`), mobile-first, readable on small screens.
- **Strict domain scoping** — the assistant stays in the bar: cocktails, mixology, ingredients, bar techniques, history, and food pairings. Off-topic questions are politely redirected.

---

## Documentation

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the app works: layers, startup and chat data flows, state machines (`ChatPhase`, `SetupStatus`), model lifecycle. (Spanish)
- [`docs/CODE_WALKTHROUGH.md`](docs/CODE_WALKTHROUGH.md) — file-by-file explanation of the code with the reasoning behind each decision. (Spanish)
- [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — known issues and fixes: iOS accent bug, CPU fallback, gated model, web limitation, clean install. (Spanish)

---

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI | Flutter (Material 3) |
| Language | Dart `^3.12.0` |
| Local LLM runtime | [`flutter_edge_ai`](https://pub.dev/packages/flutter_edge_ai) `^2.4.1` |
| Inference engine | [`flutter_edge_ai_litertlm`](https://pub.dev/packages/flutter_edge_ai_litertlm) `^1.15.0` (LiteRT LM) |
| Model | `gemma-4-E2B-it.litertlm` (Gemma 4 E2B, instruction-tuned) |
| Local storage | [`shared_preferences`](https://pub.dev/packages/shared_preferences) `^2.5.5` |
| File paths | [`path_provider`](https://pub.dev/packages/path_provider) `^2.1.6` |
| Markdown rendering | [`flutter_markdown_plus`](https://pub.dev/packages/flutter_markdown_plus) `^1.0.11` |
| External links | [`url_launcher`](https://pub.dev/packages/url_launcher) `^6.3.2` |
| Lints | [`flutter_lints`](https://pub.dev/packages/flutter_lints) `^6.0.0` |

---

## Project Structure

```
lib/
├── main.dart                       # App entry — initializes FlutterEdgeAi + LiteRtLmEngine
├── app/
│   ├── app.dart                    # MaterialApp + bootstrap (decides setup vs. chat)
│   └── theme.dart                  # Dark Material 3 theme
├── core/
│   ├── model/
│   │   ├── model_service.dart      # Singleton: model load, chat lifecycle, streaming
│   │   └── model_config.dart       # Sealed ModelConfig + GemmaModel (URL, type, limits)
│   ├── persona/
│   │   └── cocktail_system_prompt.dart  # Bartender persona + response format
│   └── storage/
│       └── chat_storage.dart       # Persists chat history in shared_preferences
└── features/
    └── chat/
        ├── models/
        │   ├── chat_controller.dart # State controller (initialize, send, cancel, reset)
        │   └── chat_message.dart    # Message model
        └── ui/
            ├── chat_screen.dart     # Main chat screen
            ├── setup_screen.dart    # First-run model download screen
            └── widgets/
                ├── message_bubble.dart
                ├── model_status_card.dart
                ├── typing_indicator.dart
                ├── input_bar.dart
                └── empty_state.dart
```

---

## Getting Started

### Prerequisites

- **Flutter SDK** with Dart `^3.12.0` (the packages `flutter_edge_ai ^2.4.1` and `flutter_edge_ai_litertlm ^1.15.0` require Flutter `>=3.44.0`)
- A target platform toolchain installed and configured:
  - **iOS** — Xcode + CocoaPods (deployment target `15.0`+, this project uses `16.0`)
  - **Android** — Android Studio + Android SDK / NDK (**`minSdk 30`**, `arm64-v8a` only)
  - **macOS** — Xcode command-line tools + CocoaPods (the Podfile carries a LiteRT-LM `post_install` phase)
  - **Windows / Linux / Web** — standard Flutter desktop / web toolchains

Verify your setup:

```bash
flutter doctor
```

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
# Default device
flutter run

# Pick a specific target
flutter run -d macos
flutter run -d ios
flutter run -d android
flutter run -d chrome
```

On first launch the **Setup Screen** will appear. Tap **Download** to fetch the Gemma 4 E2B model from Hugging Face (≈ 2.59 GB). Once the model is on disk, the app boots directly into the chat screen on subsequent runs.

> Some Hugging Face models are gated. If you receive an authorization error, paste a Hugging Face access token in the setup screen; it will be used only for that download.

> **Web note:** the web build initializes the LiteRT-LM engine (`cache_api.js`, `opfs_helper.js` and the `@litert-lm/core` module are loaded in `web/index.html`), but the native `gemma-4-E2B-it.litertlm` file only runs on native platforms. On web, generation requires a dedicated `-web.litertlm` web export of the model.

---

## How It Works

1. **`main.dart`** calls `FlutterEdgeAi.initialize(...)` with the LiteRT LM inference engine before `runApp`.
2. **`app.dart` → `_Bootstrap`** checks whether the model is already installed on the device:
   - Yes → `ChatScreen`
   - No  → `SetupScreen`
3. **`SetupScreen`** downloads the model file, reports progress, then transitions to the chat.
4. **`ModelService`** is a singleton that owns the `InferenceModel` and `InferenceChat` instances, exposes streaming responses, and handles cancel / reset / dispose. It is model-agnostic: the concrete model comes from an injectable `ModelConfig` (defaults to `GemmaModel`).
5. **`ChatController`** drives the UI state: it feeds the system prompt, forwards user messages, listens to token streams, and persists the conversation through `ChatStorage`.
6. **`cocktail_system_prompt.dart`** defines the bartender persona, the recipe response format, and strict scope rules so the model stays on-topic.

---

## Configuring the Model

All model-related values live in [`lib/core/model/model_config.dart`](lib/core/model/model_config.dart), in the `GemmaModel` implementation of the sealed `ModelConfig`:

| `ModelConfig` getter | `GemmaModel` value |
| --- | --- |
| `url` | `https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm` |
| `fileName` | `gemma-4-E2B-it.litertlm` |
| `modelType` | `ModelType.gemma4` |
| `contextTokens` | `2048` |
| `maxOutputTokens` | `512` |
| `topK` | `1` (greedy) |
| `sizeBytes` | `2.59 GB` |

To target a different model, add another `final class` extending `ModelConfig` and assign it to `ModelService.instance.config` (the default is `kDefaultModel = GemmaModel()`).

---

## Available Scripts

```bash
flutter pub get        # Install / update dependencies
flutter run            # Run on a connected device / simulator
flutter build apk      # Build an Android APK
flutter build ios      # Build an iOS app
flutter build macos    # Build the macOS app
flutter test           # Run unit & widget tests
flutter analyze        # Static analysis (uses flutter_lints)
flutter clean          # Remove build artifacts
```

---

## Reset & Clean Install (macOS dev)

If the macOS sandbox or derived data gets into a bad state during development, the original developer used this recipe:

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

---

## Scope & Safety Notes

- The assistant is **strictly** scoped to cocktails, mixology, bar service, alcoholic and non-alcoholic ingredients for mixed drinks, preparation techniques, cocktail history, food pairings, and bar culture. It will not answer unrelated questions (programming, medicine, news, general tech support, etc.) and will redirect you back to the bar.
- It will **not** give medical advice. For people in recovery it recommends seeking professional help.
- It will **not** invent specific commercial brands and will be transparent when it is uncertain about a recipe.
- For legal questions about serving alcohol, it recommends checking local regulations.
- Responses are tuned to be concise (≈ 80–200 words) and mobile-friendly.

---

## Known Limitations

- **Accented characters on iOS (physical/hardware keyboard):** typing accented letters can produce duplicated/garbled results (e.g. `más` → `m´ás`). This is an **upstream Flutter engine bug** ([flutter/flutter#146486](https://github.com/flutter/flutter/issues/146486)), not specific to this app, and reproduces in any Flutter app on iOS with an external keyboard. Workaround: on the Simulator disable **I/O → Keyboard → Connect Hardware Keyboard**, or use the on-screen keyboard. A fix is pending in [PR #191062](https://github.com/flutter/flutter/pull/191062); update Flutter (`flutter upgrade`) once it lands. See [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md).
- **Web generation requires a web model export:** the native `gemma-4-E2B-it.litertlm` file runs only on native platforms. Web needs a dedicated `-web.litertlm` export of the model.

---

## License

This project is private / unpublished (`publish_to: "none"` in `pubspec.yaml`). Add a license of your choice before distributing.
