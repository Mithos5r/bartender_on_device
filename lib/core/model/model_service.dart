import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import 'model_config.dart';

/// Owns the model lifecycle: detection, download, loading into memory and the
/// `InferenceChat` used to stream responses.
///
/// This class is deliberately model-agnostic: everything concrete comes from
/// the injected [config]. It is a singleton because only one copy of the model
/// (multiple GB) should ever live in memory at a time.
class ModelService {
  ModelService._();

  static final ModelService instance = ModelService._();

  /// Active model description. Defaults to [kDefaultModel]; assign another
  /// [ModelConfig] to target a different model.
  ModelConfig config = kDefaultModel;

  InferenceModel? _model;
  InferenceChat? _chat;

  InferenceModel? get model => _model;
  InferenceChat? get chat => _chat;
  bool get hasModel => _model != null;

  Future<bool> isModelInstalled() async {
    return await FlutterEdgeAi.isModelInstalled(config.fileName);
  }

  Future<void> downloadModel({
    required void Function(int progress) onProgress,
    String? huggingFaceToken,
  }) async {
    await FlutterEdgeAi.installModel(
          modelType: config.modelType,
          fileType: config.fileType,
        )
        .fromNetwork(config.url, token: huggingFaceToken)
        .withProgress(onProgress)
        .install();
  }

  Future<InferenceModel> loadModel({PreferredBackend? preferredBackend}) async {
    _model = await FlutterEdgeAi.getActiveModel(
      maxTokens: config.contextTokens,
      preferredBackend: preferredBackend ?? config.preferredBackend,
    );
    return _model!;
  }

  Future<InferenceChat> createChat({required String systemInstruction}) async {
    if (_model == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
    _chat = await _model!.createChat(
      systemInstruction: systemInstruction,
      modelType: config.modelType,
      maxOutputTokens: config.maxOutputTokens,
      topK: config.topK,
    );
    return _chat!;
  }

  Stream<String> sendMessageStream(InferenceChat chat, String text) async* {
    await chat.addQueryChunk(Message.text(text: text, isUser: true));
    await for (final response in chat.generateChatResponseAsync()) {
      if (response is TextResponse) {
        yield response.token;
      }
    }
  }

  Future<void> cancel() async {
    await _chat?.stopGeneration();
  }

  Future<void> resetChat() async {
    await _chat?.close();
    _chat = null;
  }

  Future<void> dispose() async {
    await _chat?.close();
    _chat = null;
    await _model?.close();
    _model = null;
  }
}
