import 'package:flutter/material.dart';

class InputBar extends StatefulWidget {
  const InputBar({
    super.key,
    required this.onSend,
    required this.onCancel,
    required this.isGenerating,
  });

  final Future<void> Function(String text) onSend;
  final Future<void> Function() onCancel;
  final bool isGenerating;

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final canSend = _controller.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isGenerating) return;
    _controller.clear();
    setState(() => _canSend = false);
    await widget.onSend(text);
  }

  Future<void> _handleCancel() async {
    await widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isGenerating,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                decoration: InputDecoration(
                  hintText: widget.isGenerating
                      ? 'Esperando respuesta…'
                      : 'Pregúntale algo al bartender…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.isGenerating)
              IconButton.filled(
                onPressed: _handleCancel,
                tooltip: 'Detener',
                icon: const Icon(Icons.stop),
              )
            else
              IconButton.filled(
                onPressed: _canSend ? _handleSend : null,
                tooltip: 'Enviar',
                icon: const Icon(Icons.send),
              ),
          ],
        ),
      ),
    );
  }
}
