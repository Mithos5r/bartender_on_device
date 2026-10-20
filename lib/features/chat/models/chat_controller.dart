import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/model/model_service.dart';
import '../../../core/persona/cocktail_system_prompt.dart';
import '../../../core/storage/chat_storage.dart';
import '../../../core/model/chat_message.dart';

enum ChatPhase { uninitialized, ready, generating, error }

class ChatController extends ChangeNotifier {
  ChatController({ModelService? service, ChatStorage? storage})
    : _service = service ?? ModelService.instance,
      _storage = storage ?? ChatStorage.instance;

  final ModelService _service;
  final ChatStorage _storage;

  final List<ChatMessage> _messages = [];
  ChatPhase _phase = ChatPhase.uninitialized;
  String? _errorMessage;
  bool _isModelReady = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatPhase get phase => _phase;
  String? get errorMessage => _errorMessage;
  bool get isModelReady => _isModelReady;
  bool get isGenerating => _phase == ChatPhase.generating;
  bool get isReady => _phase == ChatPhase.ready;

  Future<void> initialize() async {
    try {
      _phase = ChatPhase.uninitialized;
      notifyListeners();

      _messages.clear();
      _messages.addAll(await _storage.loadHistory());
      notifyListeners();

      if (!_service.hasModel) {
        await _service.loadModel();
      }
      if (_service.chat == null) {
        await _service.createChat(systemInstruction: cocktailSystemPrompt);
      }

      _isModelReady = true;
      _phase = ChatPhase.ready;
      notifyListeners();
    } catch (e) {
      _phase = ChatPhase.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isGenerating) return;
    if (!_isModelReady) {
      _errorMessage = 'El modelo aún no está listo.';
      _phase = ChatPhase.error;
      notifyListeners();
      return;
    }

    final userMessage = ChatMessage(
      role: MessageRole.user,
      text: trimmed,
      timestamp: DateTime.now(),
      status: MessageStatus.done,
    );
    _messages.add(userMessage);

    final assistantMessage = ChatMessage(
      role: MessageRole.assistant,
      text: '',
      timestamp: DateTime.now(),
      status: MessageStatus.streaming,
    );
    _messages.add(assistantMessage);

    _phase = ChatPhase.generating;
    _errorMessage = null;
    notifyListeners();

    await _persist();

    try {
      final chat = _service.chat!;
      await for (final token in _service.sendMessageStream(chat, trimmed)) {
        assistantMessage.text += token;
        notifyListeners();
      }
      assistantMessage.status = MessageStatus.done;
      _phase = ChatPhase.ready;
      notifyListeners();
      await _persist();
    } catch (e) {
      assistantMessage.text = assistantMessage.text.isEmpty
          ? 'Error: $e'
          : assistantMessage.text;
      assistantMessage.status = MessageStatus.error;
      _phase = ChatPhase.error;
      _errorMessage = e.toString();
      notifyListeners();
      await _persist();
    }
  }

  Future<void> cancel() async {
    if (!isGenerating) return;
    await _service.cancel();
    final lastAssistant = _messages.lastWhere(
      (m) => m.role == MessageRole.assistant && m.isStreaming,
      orElse: () => _messages.last,
    );
    lastAssistant.status = MessageStatus.done;
    _phase = ChatPhase.ready;
    notifyListeners();
    await _persist();
  }

  Future<void> clearHistory() async {
    _messages.clear();
    await _storage.clearHistory();
    await _service.resetChat();
    await _service.createChat(systemInstruction: cocktailSystemPrompt);
    notifyListeners();
  }

  Future<void> _persist() async {
    final persistable = _messages
        .where((m) => m.status != MessageStatus.streaming)
        .toList();
    await _storage.saveHistory(persistable);
  }

  @override
  void dispose() {
    unawaited(_service.dispose());
    super.dispose();
  }
}
