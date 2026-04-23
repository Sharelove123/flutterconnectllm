import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:runanywhere/runanywhere.dart';

import '../../../models/chat_message_model.dart';
import '../repository/llm_repository.dart';

// ─── Providers ──────────────────────────────────────────────

/// Singleton repository instance.
final llmRepositoryProvider = Provider<LlmRepository>((ref) {
  return LlmRepository();
});

/// Main chat state notifier.
final chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(() => ChatController());

// ─── State ──────────────────────────────────────────────────

class ChatState {
  final bool isInitializing;
  final bool isModelDownloaded;
  final bool isDownloading;
  final double downloadProgress;
  final bool isLoadingModel;
  final bool isModelReady;
  final List<ChatMessageModel> messages;
  final bool isGenerating;
  final String currentStreamText;

  const ChatState({
    this.isInitializing = false,
    this.isModelDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
    this.isLoadingModel = false,
    this.isModelReady = false,
    this.messages = const [],
    this.isGenerating = false,
    this.currentStreamText = '',
  });

  ChatState copyWith({
    bool? isInitializing,
    bool? isModelDownloaded,
    bool? isDownloading,
    double? downloadProgress,
    bool? isLoadingModel,
    bool? isModelReady,
    List<ChatMessageModel>? messages,
    bool? isGenerating,
    String? currentStreamText,
  }) {
    return ChatState(
      isInitializing: isInitializing ?? this.isInitializing,
      isModelDownloaded: isModelDownloaded ?? this.isModelDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      isLoadingModel: isLoadingModel ?? this.isLoadingModel,
      isModelReady: isModelReady ?? this.isModelReady,
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      currentStreamText: currentStreamText ?? this.currentStreamText,
    );
  }
}

// ─── Controller ─────────────────────────────────────────────

class ChatController extends Notifier<ChatState> {
  LLMStreamingResult? _streamingResult;
  bool _startupCheckStarted = false;

  @override
  ChatState build() {
    unawaited(_loadDownloadedModelOnStartup());
    return const ChatState(isInitializing: true);
  }

  LlmRepository get _repo => ref.read(llmRepositoryProvider);

  Future<void> _loadDownloadedModelOnStartup() async {
    if (_startupCheckStarted) return;
    _startupCheckStarted = true;

    try {
      await _repo.ensureInitialized();
      final downloaded = await _repo.isModelDownloaded();

      if (!downloaded) {
        state = state.copyWith(
          isInitializing: false,
          isModelDownloaded: false,
        );
        return;
      }

      state = state.copyWith(
        isInitializing: false,
        isModelDownloaded: true,
        isLoadingModel: true,
      );

      await _repo.loadModel();
      state = state.copyWith(isModelReady: true);
    } catch (e) {
      _addErrorMessage('Startup model load failed: $e');
    } finally {
      state = state.copyWith(
        isInitializing: false,
        isLoadingModel: false,
      );
    }
  }

  /// Download the model (shows progress) then load it.
  Future<void> downloadAndLoad() async {
    if (state.isInitializing || state.isDownloading || state.isLoadingModel) {
      return;
    }

    // ── Download ──
    state = state.copyWith(isInitializing: true);
    try {
      await _repo.ensureInitialized();
      final downloaded = await _repo.isModelDownloaded();
      state = state.copyWith(
        isInitializing: false,
        isModelDownloaded: downloaded,
      );
    } catch (e) {
      state = state.copyWith(isInitializing: false);
      _addErrorMessage('SDK initialization failed: $e');
      return;
    }

    // Download
    if (!state.isModelDownloaded) {
      state = state.copyWith(isDownloading: true, downloadProgress: 0.0);

      try {
        await for (final progress in _repo.downloadModel()) {
          state = state.copyWith(downloadProgress: progress.percentage);
          if (progress.state == DownloadProgressState.completed ||
              progress.state == DownloadProgressState.failed) {
            break;
          }
        }
        state = state.copyWith(isDownloading: false, isModelDownloaded: true);
      } catch (e) {
        state = state.copyWith(isDownloading: false);
        _addErrorMessage('Download failed: $e');
        return;
      }
    }

    // ── Load ──
    state = state.copyWith(isLoadingModel: true);
    try {
      await _repo.loadModel();
      state = state.copyWith(isModelReady: true);
    } catch (e) {
      _addErrorMessage('Load failed: $e');
    } finally {
      state = state.copyWith(isLoadingModel: false);
    }
  }

  /// Send a user message and stream the LLM response.
  Future<void> sendMessage(String text) async {
    if (!state.isModelReady || text.trim().isEmpty || state.isGenerating) {
      return;
    }

    // Add user message
    final updatedMessages = [
      ...state.messages,
      ChatMessageModel(text: text.trim(), isUser: true),
    ];
    state = state.copyWith(
      messages: updatedMessages,
      isGenerating: true,
      currentStreamText: '',
    );

    try {
      _streamingResult = await _repo.generateStream(text.trim());

      String accumulated = '';
      await for (final token in _streamingResult!.stream) {
        accumulated += token;
        state = state.copyWith(currentStreamText: accumulated);
      }

      final result = await _streamingResult!.result;

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessageModel(
            text: accumulated,
            isUser: false,
            tokensPerSecond: result.tokensPerSecond,
            totalTokens: result.tokensUsed,
          ),
        ],
        isGenerating: false,
        currentStreamText: '',
      );
    } catch (e) {
      _addErrorMessage('Error: $e');
      state = state.copyWith(isGenerating: false, currentStreamText: '');
    }
  }

  /// Cancel in-progress generation.
  void stopGeneration() {
    _streamingResult?.cancel();
    final streamText = state.currentStreamText;
    if (streamText.isNotEmpty) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessageModel(
            text: '$streamText\n\n⛔ Generation stopped',
            isUser: false,
          ),
        ],
      );
    }
    state = state.copyWith(isGenerating: false, currentStreamText: '');
  }

  /// Clear all messages.
  void clearChat() {
    state = state.copyWith(messages: []);
  }

  void _addErrorMessage(String msg) {
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessageModel(text: msg, isUser: false, isError: true),
      ],
    );
  }
}
