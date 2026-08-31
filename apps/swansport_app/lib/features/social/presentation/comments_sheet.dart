import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';

/// Yorumlar sayfasını alttan açar. Eklenen yorum sayısını döner.
Future<int?> showCommentsSheet(BuildContext context, String postId) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(postId: postId),
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
  bool _sending = false;
  int _added = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(socialServiceProvider).addComment(widget.postId, text);
      _ctrl.clear();
      _added++;
      ref.invalidate(postCommentsProvider(widget.postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yorum gönderilemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);
    final async = ref.watch(postCommentsProvider(widget.postId));
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, __) {},
      child: Container(
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: grip, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(width: 20),
                Text('Yorumlar', style: SwanType.h3(ink)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, _added),
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: SwanColors.textSecondary),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Divider(color: line, height: 16),

            Expanded(
              child: async.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: kTeal)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Yorumlar yüklenemedi: $e',
                        textAlign: TextAlign.center,
                        style: SwanType.caption(SwanColors.textSecondary)),
                  ),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mode_comment_outlined,
                              size: 34, color: SwanColors.textSecondary),
                          const SizedBox(height: 10),
                          Text('Henüz yorum yok',
                              style: SwanType.bodySm(ink, w: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('İlk yorumu sen yaz.',
                              style: SwanType.caption(SwanColors.textSecondary)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _tile(isDark, list[i]),
                  );
                },
              ),
            ),

            // Yorum yazma alanı
            Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + bottom),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    style: SwanType.bodySm(ink),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Yorum yaz…',
                      hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                      filled: true,
                      fillColor: alt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide:
                              const BorderSide(color: kTeal, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(13),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 19),
                  ),
                ),
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
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Widget _tile(bool isDark, CommentRow c) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SocialAvatar(
            initials: c.initials,
            imageUrl: c.authorAvatarUrl,
            size: 36,
            gradientIndex: (c.authorName ?? 'x').length % 4,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(c.authorName ?? 'Kullanıcı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(ink, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text(shortAgo(c.createdAt),
                      style: SwanType.caption(SwanColors.textSecondary)),
                  if (c.profileId ==
                      Supabase.instance.client.auth.currentUser?.id) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _delete(c.id),
                      behavior: HitTestBehavior.opaque,
                      child: Icon(Icons.delete_outline_rounded,
                          size: 16, color: SwanColors.textSecondary),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(c.body,
                    style: SwanType.bodySm(ink)
                        .copyWith(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
