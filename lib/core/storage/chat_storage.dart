import 'package:shared_preferences/shared_preferences.dart';

import '../model/chat_message.dart';

class ChatStorage {
  ChatStorage._();

  static final ChatStorage instance = ChatStorage._();

  static const String _kHistoryKey = 'chat_history_v1';

  Future<List<ChatMessage>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kHistoryKey);
    if (raw == null || raw.isEmpty) return [];
    return chatMessagesFromJson(raw);
  }

  Future<void> saveHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHistoryKey, chatMessagesToJson(messages));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kHistoryKey);
  }
}
