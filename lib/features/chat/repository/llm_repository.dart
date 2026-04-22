import 'dart:async';
import 'dart:io';

import 'package:runanywhere/runanywhere.dart';
import 'package:runanywhere/native/dart_bridge.dart';
import 'package:runanywhere/native/dart_bridge_model_paths.dart';
import 'package:runanywhere_llamacpp/runanywhere_llamacpp.dart';
import 'package:runanywhere/public/configuration/sdk_environment.dart';

/// Repository for managing the on-device LLM model lifecycle:
/// registering, downloading, loading, and generating text.
class LlmRepository {
  static const defaultModelId = 'smollm2-360m-instruct-q8_0';
  static final Uri _defaultModelUrl = Uri.parse(
    'https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF/resolve/main/smollm2-360m-instruct-q8_0.gguf',
  );
  static bool _isInitialized = false;
  static bool _isAndroidBackendRegistered = false;

  /// Initialize the SDK and backend once, on demand.
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      DartBridge.initialize(SDKEnvironment.development);
      await DartBridge.modelPaths.setBaseDirectory();
    } else {
      await RunAnywhere.initialize();
      await LlamaCpp.register();
    }

    _isInitialized = true;
  }

  Future<void> _ensureAndroidBackendRegistered() async {
    if (!Platform.isAndroid || _isAndroidBackendRegistered) {
      return;
    }

    await LlamaCpp.register();
    _isAndroidBackendRegistered = true;
  }

  /// Check if the model has been downloaded to local storage.
  Future<bool> isModelDownloaded() async {
    await ensureInitialized();
    return (await _getExistingModelFilePath()) != null;
  }

  Future<String?> _getExistingModelFilePath() async {
    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(defaultModelId, InferenceFramework.llamaCpp);
    final filePath = '$modelDir/${_defaultModelUrl.pathSegments.last}';
    final file = File(filePath);
    return await file.exists() ? file.path : null;
  }

  /// Whether the LLM model is currently loaded in memory.
  bool get isModelLoaded => RunAnywhere.isModelLoaded;

  /// Download the model. Returns a stream of download progress.
  Stream<DownloadProgress> downloadModel() async* {
    await ensureInitialized();

    final modelDir = await DartBridgeModelPaths.instance
        .getModelFolderAndCreate(defaultModelId, InferenceFramework.llamaCpp);
    final filePath = '$modelDir/${_defaultModelUrl.pathSegments.last}';
    final file = File(filePath);
    await file.parent.create(recursive: true);

    final client = HttpClient();
    try {
      final request = await client.getUrl(_defaultModelUrl);
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: _defaultModelUrl,
        );
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : 0;
      var downloadedBytes = 0;

      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          downloadedBytes += chunk.length;
          yield DownloadProgress(
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes > 0 ? totalBytes : downloadedBytes,
            state: DownloadProgressState.downloading,
          );
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      yield DownloadProgress(
        bytesDownloaded: downloadedBytes,
        totalBytes: downloadedBytes,
        state: DownloadProgressState.completed,
        stage: DownloadProgressStage.completed,
      );
    } catch (_) {
      if (await file.exists()) {
        await file.delete();
      }
      yield const DownloadProgress(
        bytesDownloaded: 0,
        totalBytes: 1,
        state: DownloadProgressState.failed,
        stage: DownloadProgressStage.failed,
      );
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  /// Load the downloaded model into memory for inference.
  Future<void> loadModel() async {
    await ensureInitialized();
    await _ensureAndroidBackendRegistered();

    final modelPath = await _getExistingModelFilePath();
    if (modelPath == null) {
      throw StateError('Model file not found. Download the model first.');
    }

    if (DartBridge.llm.isLoaded) {
      DartBridge.llm.unload();
    }

    await DartBridge.llm.loadModel(
      modelPath,
      defaultModelId,
      'SmolLM2 360M Instruct Q8_0',
    );
  }

  /// Generate a streaming response for the given prompt.
  Future<LLMStreamingResult> generateStream(
    String prompt, {
    int maxTokens = 256,
    double temperature = 0.8,
  }) async {
    await ensureInitialized();
    if (Platform.isAndroid) {
      await _ensureAndroidBackendRegistered();

      final controller = StreamController<String>.broadcast();
      final allTokens = <String>[];

      final tokenStream = DartBridge.llm.generateStream(
        prompt,
        maxTokens: maxTokens,
        temperature: temperature,
      );

      DartBridge.llm.setActiveStreamSubscription(
        tokenStream.listen(
          (token) {
            allTokens.add(token);
            if (!controller.isClosed) {
              controller.add(token);
            }
          },
          onError: (Object error) {
            if (!controller.isClosed) {
              controller.addError(error);
            }
          },
          onDone: () {
            if (!controller.isClosed) {
              unawaited(controller.close());
            }
            DartBridge.llm.setActiveStreamSubscription(null);
          },
        ),
      );

      final resultFuture = controller.stream.toList().then((_) {
        return LLMGenerationResult(
          text: allTokens.join(),
          inputTokens: (prompt.length / 4).ceil(),
          tokensUsed: allTokens.length,
          modelUsed: defaultModelId,
          latencyMs: 0,
          framework: 'llamacpp',
          tokensPerSecond: 0,
        );
      });

      return LLMStreamingResult(
        stream: controller.stream,
        result: resultFuture,
        cancel: DartBridge.llm.cancelGeneration,
      );
    }

    return RunAnywhere.generateStream(
      prompt,
      options: LLMGenerationOptions(
        maxTokens: maxTokens,
        temperature: temperature,
      ),
    );
  }
}
