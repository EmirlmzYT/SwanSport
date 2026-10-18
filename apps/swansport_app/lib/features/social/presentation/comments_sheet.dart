import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import 'widgets/social_widgets.dart';

/// Yorumlar sayfasını alttan açar. Eklenen yorum sayısını döner.
Future<int?> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final keyboard = media.viewInsets.bottom;
      final availableHeight = media.size.height - media.padding.top - keyboard;
      final sheetHeight = availableHeight > 0
          ? availableHeight * (keyboard > 0 ? 1 : .84)
          : 0.0;
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: keyboard),
        child: SizedBox(
          height: sheetHeight,
          child: _CommentsSheet(postId: postId),
        ),
      );
    },
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _inputFocus = FocusNode();
  CommentRow? _replyTo;
  bool _sending = false;
  int _added = 0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onDraftChanged);
  }

  void _onDraftChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(socialServiceProvider).addComment(
            widget.postId,
            text,
            parentCommentId: _replyTo?.id,
          );
      _ctrl.clear();
      if (mounted) setState(() => _replyTo = null);
      _added++;
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yorum gönderilemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startReply(CommentRow comment) {
    setState(() => _replyTo = comment);
    _inputFocus.requestFocus();
  }

  List<(CommentRow, int)> _threaded(List<CommentRow> comments) {
    final ids = comments.map((c) => c.id).toSet();
    final children = <String?, List<CommentRow>>{};
    for (final comment in comments) {
      final parent = ids.contains(comment.parentCommentId)
          ? comment.parentCommentId
          : null;
      children.putIfAbsent(parent, () => []).add(comment);
    }
    final result = <(CommentRow, int)>[];
    final seen = <String>{};
    void visit(CommentRow comment, int depth) {
      if (!seen.add(comment.id)) return;
      result.add((comment, depth));
      for (final child in children[comment.id] ?? const <CommentRow>[]) {
        visit(child, depth + 1);
      }
    }

    for (final root in children[null] ?? const <CommentRow>[]) {
      visit(root, 0);
    }
    for (final comment in comments) {
      if (!seen.contains(comment.id)) visit(comment, 0);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(postCommentsProvider(widget.postId));
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    final gestureBottom = MediaQuery.systemGestureInsetsOf(context).bottom;
    final safeBottom = viewBottom > gestureBottom ? viewBottom : gestureBottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: SwanSpace.sm),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.inkMuted.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.sm,
                SwanSpace.sm,
                SwanSpace.sm,
              ),
              child: Row(children: [
                Text('Yorumlar', style: SwanType.h3(c.ink)),
                if (async.valueOrNull != null) ...[
                  const SizedBox(width: SwanSpace.sm),
                  Text('${async.valueOrNull!.length}',
                      style: SwanType.bodySm(c.inkMuted)),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Yorumları kapat',
                  onPressed: () => Navigator.pop(context, _added),
                  icon: Icon(Icons.close_rounded, color: c.inkMuted),
                ),
              ]),
            ),
            Divider(color: c.line, height: 1),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SwanSpace.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            size: 32, color: c.inkMuted),
                        const SizedBox(height: SwanSpace.sm),
                        Text('Yorumlar yüklenemedi',
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                        TextButton(
                          onPressed: () => ref
                              .invalidate(postCommentsProvider(widget.postId)),
                          child: const Text('Yeniden dene'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.mode_comment_outlined,
                                size: 28, color: c.inkMuted),
                          ),
                          const SizedBox(height: SwanSpace.md),
                          Text('Henüz yorum yok',
                              style:
                                  SwanType.bodySm(c.ink, w: FontWeight.w700)),
                          const SizedBox(height: SwanSpace.xs),
                          Text('İlk yorumu sen yaz.',
                              style: SwanType.bodySm(c.inkMuted)),
                        ],
                      ),
                    );
                  }
                  final threaded = _threaded(list);
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        SwanSpace.lg, SwanSpace.sm, SwanSpace.lg, SwanSpace.lg),
                    itemCount: threaded.length,
                    itemBuilder: (_, i) => Column(children: [
                      _tile(threaded[i].$1, depth: threaded[i].$2),
                      if (i + 1 < threaded.length && threaded[i + 1].$2 == 0)
                        Divider(color: c.line, height: SwanSpace.lg),
                    ]),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.line)),
              ),
              padding: EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.md,
                SwanSpace.lg,
                SwanSpace.md + safeBottom,
              ),
              child: Column(children: [
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                    child: Row(children: [
                      Icon(Icons.reply_rounded, size: 17, color: c.accent),
                      const SizedBox(width: SwanSpace.xs),
                      Expanded(
                          child: Text(
                        '${_replyTo!.authorName ?? 'Kullanıcı'} kişisine yanıt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      )),
                      IconButton(
                        tooltip: 'Yanıtı iptal et',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _replyTo = null),
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: c.inkMuted),
                      ),
                    ]),
                  ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _inputFocus,
                      minLines: 1,
                      maxLines: 4,
                      style: SwanType.bodySm(c.ink),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText:
                            _replyTo == null ? 'Yorum yaz…' : 'Yanıtını yaz…',
                        hintStyle: SwanType.bodySm(c.inkMuted),
                        filled: true,
                        fillColor: c.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: SwanSpace.md, vertical: SwanSpace.md),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  IconButton.filled(
                    tooltip: 'Yorumu gönder',
                    onPressed:
                        _sending || _ctrl.text.trim().isEmpty ? null : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: c.accentFill,
                      foregroundColor: c.onAccent,
                      disabledBackgroundColor: c.surfaceAlt,
                      disabledForegroundColor: c.inkMuted,
                    ),
                    icon: _sending
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.onAccent,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  ),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(socialServiceProvider).deleteComment(id);
      ref.invalidate(postCommentsProvider(widget.postId));
      if (_added > 0) _added--;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }

  Widget _tile(CommentRow comment, {required int depth}) {
    final c = context.swan;
    final isReply = depth > 0;
    final isMine =
        comment.profileId == Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isReply ? SwanSpace.lg : 0,
        SwanSpace.md,
        0,
        SwanSpace.md,
      ),
      child: Container(
        decoration: isReply
            ? BoxDecoration(
                border: Border(left: BorderSide(color: c.line, width: 2)),
              )
            : null,
        padding: EdgeInsets.only(left: isReply ? SwanSpace.md : 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialAvatar(
              initials: comment.initials,
              imageUrl: comment.authorAvatarUrl,
              size: isReply ? 32 : 38,
              gradientIndex: (comment.authorName ?? 'x').length % 4,
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        comment.authorName ?? 'Kullanıcı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Text(shortAgo(comment.createdAt),
                        style: SwanType.caption(c.inkMuted)),
                    if (isMine) ...[
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Yorum seçenekleri',
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_horiz_rounded,
                            size: 19, color: c.inkMuted),
                        onSelected: (_) => _delete(comment.id),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'delete', child: Text('Sil')),
                        ],
                      ),
                    ],
                  ]),
                  Text(
                    comment.body,
                    style: SwanType.bodySm(c.ink).copyWith(height: 1.4),
                  ),
                  if (ref.read(socialServiceProvider).commentRepliesAvailable)
                    InkWell(
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                      onTap: () => _startReply(comment),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: SwanSpace.sm),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.reply_rounded,
                                size: 16, color: c.inkMuted),
                            const SizedBox(width: SwanSpace.xs),
                            Text('Yanıtla',
                                style: SwanType.caption(c.inkMuted,
                                    w: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
