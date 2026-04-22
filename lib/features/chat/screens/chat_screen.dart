import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../models/chat_message_model.dart';
import '../controller/chat_controller.dart';

/// Main chat screen — handles model setup + conversation UI.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);

    // Auto-scroll when streaming text changes
    ref.listen(chatControllerProvider, (prev, next) {
      if (prev?.currentStreamText != next.currentStreamText ||
          prev?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: _buildAppBar(chatState, controller),
      body: chatState.isModelReady
          ? _buildChatBody(chatState, controller)
          : _buildSetupBody(chatState, controller),
    );
  }

  // ─── App bar ────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      ChatState chatState, ChatController controller) {
    return AppBar(
      title: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: chatState.isModelReady
                  ? AppTheme.successGreen
                  : AppTheme.errorRed,
              boxShadow: [
                BoxShadow(
                  color: (chatState.isModelReady
                          ? AppTheme.successGreen
                          : AppTheme.errorRed)
                      .withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Text('Local LLM Chat'),
        ],
      ),
      actions: [
        if (chatState.messages.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            onPressed: controller.clearChat,
            tooltip: 'Clear chat',
          ),
      ],
    );
  }

  // ─── Setup body (download / load) ──────────────────────────
  Widget _buildSetupBody(ChatState chatState, ChatController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentPurple.withValues(alpha: 0.15),
                    AppTheme.accentCyan.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 56,
                color: AppTheme.accentPurple,
              ),
            ),
            const SizedBox(height: 28),

            Text('On-Device LLM',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 10),
            Text(
              'Download & load a small language model\n(SmolLM2 360M · ~400 MB) to chat offline.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 14,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 36),

            if (chatState.messages
                .where((message) => message.isError)
                .isNotEmpty) ...[
              _buildErrorPanel(chatState.messages.lastWhere(
                (message) => message.isError,
              )),
              const SizedBox(height: 24),
            ],

            if (chatState.isInitializing) ...[
              const CircularProgressIndicator(color: AppTheme.accentPurple),
              const SizedBox(height: 14),
              Text(
                'Initializing local runtime...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Download progress
            if (chatState.isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: chatState.downloadProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.accentPurple),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Downloading… ${(chatState.downloadProgress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Loading spinner
            if (chatState.isLoadingModel && !chatState.isDownloading) ...[
              const CircularProgressIndicator(color: AppTheme.accentPurple),
              const SizedBox(height: 14),
              Text(
                'Loading model into memory…',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],

            // Action button
            if (!chatState.isInitializing &&
                !chatState.isDownloading &&
                !chatState.isLoadingModel) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: controller.downloadAndLoad,
                  child: Text(
                    chatState.isModelDownloaded
                        ? 'Load Model'
                        : 'Download & Load Model',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPanel(ChatMessageModel message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.25)),
      ),
      child: Text(
        message.text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.errorRed,
              height: 1.4,
            ),
      ),
    );
  }

  // ─── Chat body ─────────────────────────────────────────────
  Widget _buildChatBody(ChatState chatState, ChatController controller) {
    return Column(
      children: [
        Expanded(
          child: chatState.messages.isEmpty && !chatState.isGenerating
              ? _buildEmptyChat(controller)
              : _buildMessageList(chatState),
        ),
        _buildInputBar(chatState, controller),
      ],
    );
  }

  Widget _buildEmptyChat(ChatController controller) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_outlined,
                size: 52, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 20),
            Text(
              'Model loaded — ask anything!',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white38,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _suggestionChip('Tell me a joke', controller),
                _suggestionChip('What is AI?', controller),
                _suggestionChip('Write a haiku', controller),
                _suggestionChip('Explain gravity', controller),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, ChatController controller) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _textController.text = label;
        controller.sendMessage(label);
        _textController.clear();
      },
    );
  }

  // ─── Message list ──────────────────────────────────────────
  Widget _buildMessageList(ChatState chatState) {
    final itemCount =
        chatState.messages.length + (chatState.isGenerating ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, i) {
        // Streaming bubble
        if (i == chatState.messages.length && chatState.isGenerating) {
          return _MessageBubble(
            message: ChatMessageModel(
              text: chatState.currentStreamText.isEmpty
                  ? '…'
                  : chatState.currentStreamText,
              isUser: false,
            ),
            isStreaming: true,
          );
        }
        return _MessageBubble(message: chatState.messages[i]);
      },
    );
  }

  // ─── Input bar ─────────────────────────────────────────────
  Widget _buildInputBar(ChatState chatState, ChatController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) {
                  controller.sendMessage(_textController.text);
                  _textController.clear();
                },
                enabled: !chatState.isGenerating,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type your message…',
                ),
              ),
            ),
            const SizedBox(width: 10),
            chatState.isGenerating
                ? _circleButton(
                    icon: Icons.stop_rounded,
                    color: AppTheme.errorRed,
                    onPressed: controller.stopGeneration,
                  )
                : _circleButton(
                    icon: Icons.send_rounded,
                    color: AppTheme.accentPurple,
                    onPressed: () {
                      controller.sendMessage(_textController.text);
                      _textController.clear();
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  MESSAGE BUBBLE WIDGET
// ═══════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isStreaming;

  const _MessageBubble({required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.2),
              child: const Icon(Icons.smart_toy_outlined,
                  size: 18, color: AppTheme.accentPurple),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.accentPurple.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                border: Border.all(
                  color: isUser
                      ? AppTheme.accentPurple.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: message.isError
                          ? AppTheme.errorRed
                          : Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),
                  // Metrics for completed AI responses
                  if (!isUser &&
                      !isStreaming &&
                      message.tokensPerSecond != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${message.tokensPerSecond!.toStringAsFixed(1)} tok/s · ${message.totalTokens ?? 0} tokens',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white24),
                    ),
                  ],
                  // Streaming indicator
                  if (isStreaming) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.accentPurple.withValues(alpha: 0.15),
              child: const Icon(Icons.person_outline_rounded,
                  size: 18, color: Colors.white54),
            ),
        ],
      ),
    );
  }
}
