import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/model/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    final bg = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHigh;
    final fg = isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final base = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(
        color: fg,
        fontSize: 15,
        height: 1.4,
      ),
      pPadding: const EdgeInsets.symmetric(vertical: 4),
      strong: TextStyle(color: fg, fontWeight: FontWeight.w700),
      em: TextStyle(color: fg, fontStyle: FontStyle.italic),
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: fg,
        fontWeight: FontWeight.bold,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: fg,
        fontWeight: FontWeight.bold,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: fg,
        fontWeight: FontWeight.bold,
      ),
      h4: theme.textTheme.titleSmall?.copyWith(
        color: fg,
        fontWeight: FontWeight.bold,
      ),
      listBullet: theme.textTheme.bodyMedium?.copyWith(color: fg, fontSize: 15),
      listIndent: 20,
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: fg,
        backgroundColor: theme.colorScheme.surface,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      tableHead: TextStyle(color: fg, fontWeight: FontWeight.bold),
      tableBody: TextStyle(color: fg),
      tableBorder: TableBorder.all(color: theme.colorScheme.outlineVariant),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      a: TextStyle(
        color: theme.colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: theme.colorScheme.primary,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.isError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Error',
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (message.text.isEmpty && message.isStreaming)
                    Text(
                      '…',
                      style: TextStyle(color: fg, fontSize: 15, height: 1.4),
                    )
                  else
                    MarkdownBody(
                      data: message.text,
                      styleSheet: base,
                      selectable: true,
                      onTapLink: (text, href, title) {
                        if (href != null) {
                          launchUrl(Uri.parse(href));
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
