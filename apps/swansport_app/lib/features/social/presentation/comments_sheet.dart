import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/friendly_error.dart';

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
      return Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              width: double.infinity,
              height: sheetHeight,
              child: _CommentsSheet(postId: postId),
            ),
          ),
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
  final _scrollController = ScrollController();
  CommentRow? _replyTo;
  List<CommentRow>? _lastComments;
  String? _composerError;
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final draft = _ctrl.text;
    final text = draft.trim();
    if (text.isEmpty || _sending) return;
    final reply = _replyTo;
    setState(() {
      _sending = true;
      _composerError = null;
    });
    var sent = false;
    try {
      await ref.read(socialServiceProvider).addComment(
            widget.postId,
            text,
            parentCommentId: reply?.id,
          );
      sent = true;
      _added++;
      if (mounted) {
        setState(() {
          if (_ctrl.text == draft) {
            _ctrl.clear();
            if (_replyTo?.id == reply?.id) _replyTo = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _composerError = friendlyErrorMessage(
            e,
            defaultMessage: 'Yorum gönderilemedi. Lütfen tekrar deneyin.',
          );
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
    if (sent) await _reloadComments(scrollToBottom: true);
  }

  Future<void> _reloadComments({
    bool scrollToBottom = false,
    String failureMessage = 'Yorum gönderildi ancak liste yenilenemedi.',
  }) async {
    final provider = postCommentsProvider(widget.postId);
    ref.invalidate(provider);
    try {
      final comments = await ref.read(provider.future);
      if (!mounted) return;
      setState(() => _lastComments = comments);
      if (scrollToBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _composerError = failureMessage);
      }
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
    final loadedComments = async.valueOrNull;
    if (loadedComments != null) _lastComments = loadedComments;
    final visibleComments = loadedComments ?? _lastComments;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;
    final gestureBottom = MediaQuery.systemGestureInsetsOf(context).bottom;
    final safeBottom = keyboardVisible
        ? 0.0
        : viewBottom > gestureBottom
            ? viewBottom
            : gestureBottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
      child: Container(
        key: const Key('comments-sheet'),
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
              key: const Key('comments-drag-handle'),
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
                if (visibleComments != null) ...[
                  const SizedBox(width: SwanSpace.sm),
                  Text('${visibleComments.length}',
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
              child: visibleComments != null
                  ? _commentsList(visibleComments)
                  : async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(SwanSpace.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 32,
                                color: c.inkMuted,
                              ),
                              const SizedBox(height: SwanSpace.sm),
                              Text(
                                'Yorumlar yüklenemedi',
                                style: SwanType.bodySm(
                                  c.ink,
                                  w: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: () => ref.invalidate(
                                  postCommentsProvider(widget.postId),
                                ),
                                child: const Text('Yeniden dene'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: _commentsList,
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
                if (_composerError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: c.danger,
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: Text(
                            _composerError!,
                            style: SwanType.caption(c.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      readOnly: _sending,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: SwanType.bodySm(c.ink),
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

  Widget _commentsList(List<CommentRow> list) {
    final c = context.swan;
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
              child: Icon(
                Icons.mode_comment_outlined,
                size: 28,
                color: c.inkMuted,
              ),
            ),
            const SizedBox(height: SwanSpace.md),
            Text(
              'Henüz yorum yok',
              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
            ),
            const SizedBox(height: SwanSpace.xs),
            Text('İlk yorumu sen yaz.', style: SwanType.bodySm(c.inkMuted)),
          ],
        ),
      );
    }

    final byId = {for (final comment in list) comment.id: comment};
    final threaded = _threaded(list);
    return ListView.builder(
      key: const PageStorageKey('comments-list'),
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.sm,
        SwanSpace.lg,
        SwanSpace.lg,
      ),
      itemCount: threaded.length,
      itemBuilder: (_, i) {
        final comment = threaded[i].$1;
        final parent = byId[comment.parentCommentId];
        return Column(
          children: [
            _tile(
              comment,
              depth: threaded[i].$2,
              replyToName: parent?.authorName,
            ),
            if (i + 1 < threaded.length && threaded[i + 1].$2 == 0)
              Divider(color: c.line, height: SwanSpace.lg),
          ],
        );
      },
    );
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(socialServiceProvider).deleteComment(id);
      if (mounted) {
        setState(() {
          _lastComments = _lastComments
              ?.where((comment) => comment.id != id)
              .toList(growable: false);
          if (_added > 0) _added--;
        });
      }
      await _reloadComments(
        failureMessage: 'Yorum silindi ancak liste yenilenemedi.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _composerError = friendlyErrorMessage(
            e,
            defaultMessage: 'Yorum silinemedi. Lütfen tekrar deneyin.',
          );
        });
      }
    }
  }

  Widget _tile(
    CommentRow comment, {
    required int depth,
    String? replyToName,
  }) {
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
            _profileTarget(
              comment,
              child: SocialAvatar(
                initials: comment.initials,
                imageUrl: comment.authorAvatarUrl,
                size: isReply ? 32 : 38,
                gradientIndex: (comment.authorName ?? 'x').length % 4,
              ),
            ),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: _profileTarget(
                        comment,
                        child: Text(
                          comment.authorName ?? 'Kullanıcı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                        ),
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
                  if (replyToName?.trim().isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${replyToName!.trim()} kişisine yanıt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ),
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

  Widget _profileTarget(CommentRow comment, {required Widget child}) {
    final canOpen = comment.profileId.trim().isNotEmpty &&
        comment.authorName?.trim().isNotEmpty == true;
    if (!canOpen) return child;
    return Semantics(
      button: true,
      label: '${comment.authorName} profilini aç',
      child: InkWell(
        borderRadius: BorderRadius.circular(SwanRadius.sm),
        onTap: () => Navigator.pushNamed(
          context,
          '/profil',
          arguments: comment.profileId,
        ),
        child: child,
      ),
    );
  }
}
