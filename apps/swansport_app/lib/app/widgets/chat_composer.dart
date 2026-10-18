import 'package:flutter/material.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Multiline composition stays inside the resized Scaffold, not viewInsets.
class SwanChatComposer extends StatelessWidget {
  const SwanChatComposer(
      {super.key,
      required this.controller,
      required this.onSend,
      this.sending = false});

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Padding(
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.xs),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: SwanType.body(c.ink),
              decoration: InputDecoration(
                hintText: 'Mesaj yaz…',
                hintStyle: SwanType.body(c.inkMuted),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.all(SwanSpace.md),
              ),
            )),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) => IconButton.filled(
                tooltip: 'Gönder',
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(SwanSpace.xl * 2),
                  backgroundColor: c.accentFill,
                  foregroundColor: c.onAccent,
                ),
                onPressed: sending || value.text.trim().isEmpty ? null : onSend,
                icon: sending
                    ? SizedBox.square(
                        dimension: SwanSpace.lg,
                        child: CircularProgressIndicator(color: c.onAccent))
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
