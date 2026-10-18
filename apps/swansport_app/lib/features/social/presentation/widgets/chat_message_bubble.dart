import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/shared_content_card.dart';
import 'chat_presentation.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble(
      {super.key,
      required this.item,
      this.grouped = false,
      this.query = '',
      this.selected = false,
      this.onRetry});
  final ChatItem item;
  final bool grouped;
  final String query;
  final bool selected;
  final VoidCallback? onRetry;

  Future<void> _actions(BuildContext context) async {
    final m = item.message;
    if (m.body.isEmpty && onRetry == null) return;
    final c = context.swan;
    final action = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: c.surface,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(SwanSpace.md),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (m.body.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.copy_rounded),
                        title: const Text('Metni kopyala'),
                        onTap: () => Navigator.pop(context, 'copy')),
                  if (onRetry != null)
                    ListTile(
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('Tekrar gönder'),
                        onTap: () => Navigator.pop(context, 'retry')),
                ]))));
    if (!context.mounted) return;
    if (action == 'retry') onRetry?.call();
    if (action == 'copy') {
      try {
        await Clipboard.setData(ClipboardData(text: m.body));
        if (context.mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Mesaj kopyalandı')));
      } catch (_) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Metin kopyalanamadı')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final m = item.message;
    final ink = m.isMine ? c.onAccent : c.ink;
    final ranges = chatMatchRanges(m.body, query);
    final spans = <TextSpan>[];
    var end = 0;
    for (final range in ranges) {
      if (range.$1 > end)
        spans.add(TextSpan(text: m.body.substring(end, range.$1)));
      spans.add(TextSpan(
          text: m.body.substring(range.$1, range.$2),
          style: SwanType.body(c.ink, w: FontWeight.w700)
              .copyWith(backgroundColor: c.warning)));
      end = range.$2;
    }
    spans.add(TextSpan(text: m.body.substring(end)));
    return Padding(
        padding: EdgeInsets.only(
            top: grouped ? SwanSpace.xs : SwanSpace.lg, bottom: SwanSpace.xs),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment:
                m.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!m.isMine && item.senderName != null) ...[
                SizedBox.square(
                    dimension: SwanSpace.xl,
                    child: grouped
                        ? null
                        : CircleAvatar(
                            backgroundColor: c.surfaceAlt,
                            foregroundImage: item.avatarUrl == null
                                ? null
                                : NetworkImage(item.avatarUrl!),
                            onForegroundImageError:
                                item.avatarUrl == null ? null : (_, __) {},
                            child: Text(
                                item.senderName!.isEmpty
                                    ? '?'
                                    : item.senderName!.characters.first,
                                style: SwanType.caption(c.ink)))),
                const SizedBox(width: SwanSpace.sm),
              ],
              Flexible(
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .78),
                      child: Semantics(
                          selected: selected,
                          child: GestureDetector(
                              onLongPress: () => _actions(context),
                              child: DecoratedBox(
                                  decoration: BoxDecoration(
                                      color: selected
                                          ? c.warning
                                          : (m.isMine
                                              ? c.accentFill
                                              : c.surface),
                                      borderRadius:
                                          BorderRadius.circular(SwanRadius.md)),
                                  child: Padding(
                                      padding:
                                          const EdgeInsets.all(SwanSpace.xs),
                                      child: Container(
                                          padding: const EdgeInsets.all(
                                              SwanSpace.md),
                                          decoration: BoxDecoration(
                                              color: m.isMine
                                                  ? c.accentFill
                                                  : c.surface,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      SwanRadius.sm)),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (!grouped &&
                                                    !m.isMine &&
                                                    item.senderName != null)
                                                  Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom:
                                                                  SwanSpace.xs),
                                                      child: Text(
                                                          item.senderName!,
                                                          style:
                                                              SwanType.caption(
                                                                  ink,
                                                                  w: FontWeight
                                                                      .w800))),
                                                if (m.isShare)
                                                  SharedContentCard(
                                                      kind: m.sharedKind ??
                                                          m.contentType,
                                                      id: m.sharedId!,
                                                      onDark: m.isMine),
                                                if (m.body.isNotEmpty)
                                                  Text.rich(
                                                      TextSpan(children: spans),
                                                      style:
                                                          SwanType.body(ink)),
                                                const SizedBox(
                                                    height: SwanSpace.sm),
                                                Wrap(
                                                    spacing: SwanSpace.sm,
                                                    crossAxisAlignment:
                                                        WrapCrossAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                          chatTime(m.createdAt),
                                                          style:
                                                              SwanType.caption(m
                                                                      .isMine
                                                                  ? c.onAccent
                                                                  : c.inkMuted)),
                                                      if (m.isMine)
                                                        Text(chatStatus(m),
                                                            style: SwanType
                                                                .caption(ink)),
                                                      if (m.isMine)
                                                        Icon(
                                                            m.status ==
                                                                    MessageStatus
                                                                        .failed
                                                                ? Icons
                                                                    .error_outline_rounded
                                                                : m.status ==
                                                                        MessageStatus
                                                                            .sending
                                                                    ? Icons
                                                                        .schedule_rounded
                                                                    : m.isRead
                                                                        ? Icons
                                                                            .done_all_rounded
                                                                        : Icons
                                                                            .done_rounded,
                                                            size: SwanSpace.lg,
                                                            color: ink),
                                                    ]),
                                                if (onRetry != null)
                                                  TextButton.icon(
                                                      onPressed: onRetry,
                                                      style:
                                                          TextButton.styleFrom(
                                                              foregroundColor:
                                                                  ink),
                                                      icon: const Icon(Icons
                                                          .refresh_rounded),
                                                      label: const Text(
                                                          'Tekrar gönder')),
                                              ])))))))),
            ]));
  }
}
