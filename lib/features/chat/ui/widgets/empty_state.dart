import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.onSuggestionTap});

  final void Function(String suggestion) onSuggestionTap;

  static const _suggestions = <String>[
    'Recomiéndame un cóctel con ginebra',
    '¿Cómo se hace un Negroni clásico?',
    'Explícame la historia del Old Fashioned',
    'Dame un mocktail sin alcohol',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_bar, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '¿Qué te preparo?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pregúntame sobre cócteles, técnicas, historia o ingredientes.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ..._suggestions.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onSuggestionTap(s),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(s),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
