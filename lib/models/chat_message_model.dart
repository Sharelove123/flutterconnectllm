/// Data model for a chat message.
class ChatMessageModel {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final double? tokensPerSecond;
  final int? totalTokens;
  final bool isError;

  ChatMessageModel({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.tokensPerSecond,
    this.totalTokens,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessageModel copyWith({
    String? text,
    bool? isUser,
    DateTime? timestamp,
    double? tokensPerSecond,
    int? totalTokens,
    bool? isError,
  }) {
    return ChatMessageModel(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      tokensPerSecond: tokensPerSecond ?? this.tokensPerSecond,
      totalTokens: totalTokens ?? this.totalTokens,
      isError: isError ?? this.isError,
    );
  }
}
