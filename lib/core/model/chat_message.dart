import 'dart:convert';

enum MessageRole { user, assistant }

enum MessageStatus { sending, streaming, done, error }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.done,
  });

  final MessageRole role;
  String text;
  final DateTime timestamp;
  MessageStatus status;

  bool get isUser => role == MessageRole.user;
  bool get isStreaming => status == MessageStatus.streaming;
  bool get isError => status == MessageStatus.error;

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'text': text,
    'timestamp': timestamp.toIso8601String(),
    'status': status.name,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: MessageRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => MessageRole.user,
    ),
    text: json['text'] as String? ?? '',
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    status: MessageStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => MessageStatus.done,
    ),
  );

  ChatMessage copyWith({String? text, MessageStatus? status}) => ChatMessage(
    role: role,
    text: text ?? this.text,
    timestamp: timestamp,
    status: status ?? this.status,
  );
}

String chatMessagesToJson(List<ChatMessage> messages) =>
    jsonEncode(messages.map((m) => m.toJson()).toList());

List<ChatMessage> chatMessagesFromJson(String source) {
  if (source.isEmpty) return [];
  final decoded = jsonDecode(source);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(ChatMessage.fromJson)
      .toList();
}
