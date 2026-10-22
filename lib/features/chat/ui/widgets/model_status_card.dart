import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/model/model_service.dart';

enum SetupStatus { idle, checking, downloading, loading, ready, error }

class ModelStatusCard extends StatelessWidget {
  const ModelStatusCard({
    super.key,
    required this.status,
    required this.progress,
    required this.errorMessage,
  });

  final SetupStatus status;
  final int progress;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final model = ModelService.instance.config;
    final (icon, title, subtitle) = _contentFor(theme);

    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (status == SetupStatus.downloading) ...[
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text('$progress%', style: theme.textTheme.bodySmall),
            ],
            if (status == SetupStatus.loading) ...[
              const SizedBox(height: 20),
              const _LoadingBlock(message: 'Cargando modelo en memoria…'),
            ],
            if (status == SetupStatus.error && errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  errorMessage!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.storage_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${model.displayName} · ${model.sizeLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, String) _contentFor(ThemeData theme) {
    switch (status) {
      case SetupStatus.idle:
      case SetupStatus.checking:
        return (
          Icons.cloud_download_outlined,
          'Descargar modelo',
          'Se descargará una vez y luego funcionará sin internet.',
        );
      case SetupStatus.downloading:
        return (
          Icons.downloading,
          'Descargando modelo…',
          'Mantén la app abierta. La descarga usa 2.59 GB.',
        );
      case SetupStatus.loading:
        return (
          Icons.memory,
          'Cargando en memoria…',
          'Esto puede tardar 20-40 segundos.',
        );
      case SetupStatus.ready:
        return (
          Icons.check_circle_outline,
          'Modelo listo',
          'Ya puedes empezar a chatear.',
        );
      case SetupStatus.error:
        return (
          Icons.error_outline,
          'Error',
          'Revisa tu conexión o inténtalo de nuevo.',
        );
    }
  }
}

class _LoadingBlock extends StatefulWidget {
  const _LoadingBlock({required this.message});

  final String message;

  @override
  State<_LoadingBlock> createState() => _LoadingBlockState();
}

class _LoadingBlockState extends State<_LoadingBlock>
    with SingleTickerProviderStateMixin {
  late final Stopwatch _stopwatch;
  late final Timer _ticker;
  Duration _elapsed = Duration.zero;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _elapsed = _stopwatch.elapsed);
    });
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _ticker.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.memory,
                  size: 32,
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.5 + 0.5 * _pulse.value,
                  ),
                ),
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(widget.message, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          'Llevas ${_format(_elapsed)} cargando',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
