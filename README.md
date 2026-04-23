# Flutter Local LLM Chat — RunAnywhere SDK

A **minimal Flutter mobile app** that downloads, loads, and runs an LLM (SmolLM2-360M) **entirely on-device** using the [RunAnywhere SDK](https://github.com/RunanywhereAI/runanywhere-sdks).

No cloud, no API keys, no data leaves your phone.

---

## What it does

| Step | Detail |
|------|--------|
| **1. Initialize** | `RunAnywhere.initialize()` + `LlamaCpp.register()` |
| **2. Download** | Streams a ~400 MB GGUF model from HuggingFace with a progress bar |
| **3. Load** | `RunAnywhere.loadModel()` maps the model into memory |
| **4. Chat** | `RunAnywhere.generateStream()` streams tokens in real-time |

## Screenshots

> On a real device, you'll see:
> - A setup screen with a **Download & Load Model** button
> - A progress bar during download
> - A chat screen with streaming AI responses + performance metrics

## Prerequisites

- **Flutter 3.10+** (tested with 3.38.2)
- **iOS 13+** or **Android API 24+**
- A **physical device** (emulators work but will be slow)
- ~500 MB free storage for the model

## Getting Started

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on a connected device
flutter run
```

## Download APK

If you only want to install the app, download the compressed release package from:

- `apk/app-release.zip`

After downloading, extract the ZIP and install `app-release.apk` on your Android device.

### Android

The `AndroidManifest.xml` already includes `INTERNET` permission.
`minSdkVersion` is set to **24** in `build.gradle.kts`.

### iOS

No special setup needed. For iOS, just run:
```bash
cd ios && pod install && cd ..
flutter run
```

## Architecture

The project follows a feature-first architecture using Riverpod for state management:

```
lib/
├── core/
│   ├── router.dart            # GoRouter navigation setup
│   └── theme.dart             # Application theme configuration
├── features/
│   └── chat/
│       ├── controller/
│       │   └── chat_controller.dart # Riverpod state management for chat logic
│       ├── repository/
│       │   └── llm_repository.dart  # RunAnywhere SDK interactions
│       └── screens/
│           └── chat_screen.dart     # Main chat UI
├── models/
│   └── chat_message_model.dart # Data model for chat messages
└── main.dart                  # App entry point, SDK init, Riverpod ProviderScope
```

## SDK Packages Used

| Package | Purpose |
|---------|---------|
| `runanywhere: 0.16.0` | Core SDK — model management, generation API |
| `runanywhere_llamacpp: 0.16.0` | LlamaCpp backend for GGUF models |

## Key SDK APIs Demonstrated

```dart
// Initialize
await RunAnywhere.initialize();
await LlamaCpp.register();

// Register model
LlamaCpp.addModel(id: '...', name: '...', url: '...', memoryRequirement: ...);

// Download with progress
await for (final progress in RunAnywhere.downloadModel(modelId)) { ... }

// Load into memory
await RunAnywhere.loadModel(modelId);

// Stream text generation
final result = await RunAnywhere.generateStream(prompt, options: options);
await for (final token in result.stream) { ... }
```

## License

MIT — feel free to use this as a starting point.
