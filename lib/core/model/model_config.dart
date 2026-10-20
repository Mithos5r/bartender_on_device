import 'package:flutter_edge_ai/flutter_edge_ai.dart';

/// Immutable description of a local inference model: where to get it, how to
/// load it and how to run it. The app is model-agnostic — everything specific
/// to a concrete model lives in a subclass such as [GemmaModel].
sealed class ModelConfig {
  const ModelConfig();

  /// Local file name used to detect an installed model and to download it.
  String get fileName;

  /// Remote URL the model is downloaded from on first run.
  String get url;

  /// Model family understood by the inference engine.
  ModelType get modelType;

  /// Container format of the model file.
  ModelFileType get fileType;

  /// Size of the model's context window, in tokens.
  int get contextTokens;

  /// Maximum number of tokens generated per turn.
  int get maxOutputTokens;

  /// Sampling cutoff. `1` means greedy (deterministic) decoding.
  int get topK;

  /// Preferred hardware backend. The engine falls back automatically if the
  /// device does not support it.
  PreferredBackend get preferredBackend;

  /// Approximate file size in bytes (for display / preflight checks).
  double get sizeBytes;

  /// Human-readable model name for the UI.
  String get displayName;

  /// Human-readable file size for the UI, e.g. `2.59 GB`.
  String get sizeLabel;
}

/// Gemma 4 E2B, instruction-tuned, LiteRT LM export.
final class GemmaModel extends ModelConfig {
  const GemmaModel();

  @override
  String get fileName => 'gemma-4-E2B-it.litertlm';

  @override
  String get url =>
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  @override
  ModelType get modelType => ModelType.gemma4;

  @override
  ModelFileType get fileType => ModelFileType.litertlm;

  @override
  int get contextTokens => 2048;

  @override
  int get maxOutputTokens => 512;

  @override
  int get topK => 1;

  @override
  PreferredBackend get preferredBackend => PreferredBackend.gpu;

  @override
  double get sizeBytes => 2.59 * 1024 * 1024 * 1024;

  @override
  String get displayName => 'Gemma 4 E2B';

  @override
  String get sizeLabel => '2.59 GB';
}

/// The model the app ships with by default.
const ModelConfig kDefaultModel = GemmaModel();
