import 'package:flutter/material.dart';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';

import '../../../core/model/model_service.dart';
import '../../../core/persona/cocktail_system_prompt.dart';
import 'chat_screen.dart';
import 'widgets/model_status_card.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  SetupStatus _status = SetupStatus.checking;
  int _progress = 0;
  String? _errorMessage;
  String? _huggingFaceToken;
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _status = SetupStatus.checking;
    });
    try {
      final installed = await ModelService.instance.isModelInstalled();
      if (!mounted) return;
      setState(() {
        _status = installed ? SetupStatus.ready : SetupStatus.idle;
      });
      if (installed) {
        await _loadModel();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SetupStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _status = SetupStatus.downloading;
      _progress = 0;
      _errorMessage = null;
    });
    try {
      await ModelService.instance.downloadModel(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _progress = progress);
        },
        huggingFaceToken: _huggingFaceToken,
      );
      if (!mounted) return;
      await _loadModel();
    } on DownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SetupStatus.error;
        _errorMessage = e.error.toUserMessage();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SetupStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadModel() async {
    if (!mounted) return;
    setState(() {
      _status = SetupStatus.loading;
      _errorMessage = null;
    });
    try {
      await ModelService.instance.loadModel();
      await ModelService.instance.createChat(
        systemInstruction: cocktailSystemPrompt,
      );
      if (!mounted) return;
      setState(() => _status = SetupStatus.ready);
      _navigateToChat();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = SetupStatus.error;
        _errorMessage = 'No se pudo cargar el modelo: $e';
      });
    }
  }

  void _navigateToChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const ChatScreen()),
    );
  }

  Future<void> _editToken() async {
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Token de HuggingFace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Opcional. Solo necesario si el modelo es privado o tiene acceso restringido.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                hintText: 'hf_xxxxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_tokenController.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved != null) {
      setState(() => _huggingFaceToken = saved.isEmpty ? null : saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canStart =
        _status == SetupStatus.idle ||
        _status == SetupStatus.error ||
        _status == SetupStatus.ready;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bartender On Device'),
        actions: [
          if (_huggingFaceToken == null)
            IconButton(
              tooltip: 'Configurar token de HuggingFace',
              icon: const Icon(Icons.key_outlined),
              onPressed: _editToken,
            )
          else
            IconButton(
              tooltip: 'Cambiar token',
              icon: const Icon(Icons.key),
              onPressed: _editToken,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.local_bar, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Tu bartender con IA',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Funciona completamente en tu dispositivo. Sin servidores, sin internet tras la primera configuración.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              ModelStatusCard(
                status: _status,
                progress: _progress,
                errorMessage: _errorMessage,
              ),
              const SizedBox(height: 24),
              if (canStart && _status != SetupStatus.ready)
                FilledButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.download),
                  label: Text(
                    _status == SetupStatus.error
                        ? 'Reintentar descarga'
                        : 'Descargar ${ModelService.instance.config.displayName}',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              if (_status == SetupStatus.ready)
                FilledButton.icon(
                  onPressed: _navigateToChat,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('Empezar a chatear'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
