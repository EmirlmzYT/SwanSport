import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../comments_sheet.dart';
import 'report_sheet.dart';
import 'social_widgets.dart';
import '../../../../app/design/swan_type.dart';

/// Akıştaki tek gönderi kartı — Instagram benzeri.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onChanged});

  final PostRow post;
  final VoidCallback? onChanged;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked = widget.post.likedByMe;
  late int _likes = widget.post.likeCount;
  late int _comments = widget.post.commentCount;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id) {
      _liked = widget.post.likedByMe;
      _likes = widget.post.likeCount;
      _comments = widget.post.commentCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    final next = !_liked;
    setState(() {
      _busy = true;
      _liked = next;
      _likes += next ? 1 : -1;
    });
    try {
      await ref.read(socialServiceProvider).setLike(widget.post.id, next);
    } catch (_) {
      // Geri al
      if (mounted) {
        setState(() {
          _liked = !next;
          _likes += next ? -1 : 1;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openComments() async {
    final added = await showCommentsSheet(context, widget.post.id);
    if (added != null && added > 0 && mounted) {
      setState(() => _comments += added);
    }
  }


  /// Gönderi menüsü — sahibine silme, diğerlerine şikayet ve engelleme.
  Future<void> _openMenu() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final isMine =
        widget.post.authorId == Supabase.instance.client.auth.currentUser?.id;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          if (isMine) ...[
            _menuItem(ctx, Icons.edit_outlined, 'Gönderiyi düzenle', ink, () {
              Navigator.pop(ctx);
              _editPost();
            }),
            _menuItem(ctx, Icons.delete_outline_rounded, 'Gönderiyi sil',
                const Color(0xFFF43F5E), () {
              Navigator.pop(ctx);
              _confirmDelete();
            }),
          ]
          else ...[
            _menuItem(ctx, Icons.flag_outlined, 'Şikayet et',
                const Color(0xFFF43F5E), () {
              Navigator.pop(ctx);
              showReportSheet(context,
                  targetType: 'post', targetId: widget.post.id);
            }),
            _menuItem(ctx, Icons.block_rounded, 'Kullanıcıyı engelle', ink, () {
              Navigator.pop(ctx);
              _confirmBlock();
            }),
          ],
        ]),
      ),
    );
  }

  Widget _menuItem(BuildContext ctx, IconData icon, String label, Color color,
      VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 21, color: color),
      title: Text(label, style: SwanType.bodySm(color, w: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  Future<void> _confirmBlock() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Kullanıcıyı engelle',
            style: SwanType.h3(ink)),
        content: Text(
            '${widget.post.displayName} artık gönderilerini göremeyecek ve '
            'sana mesaj gönderemeyecek. Karşılıklı takip kaldırılır.',
            style: SwanType.bodySm(SwanColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Engelle',
                style: SwanType.bodySm(const Color(0xFFF43F5E), w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await ref.read(moderationServiceProvider).block(widget.post.authorId);
      ref.invalidate(hiddenProfilesProvider);
      ref.invalidate(feedProvider);
      ref.invalidate(discoverProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Kullanıcı engellendi'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Engellenemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }


  /// Gönderi metnini düzenler (görsel değişmez).
  Future<void> _editPost() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final ctrl = TextEditingController(text: widget.post.body);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Gönderiyi düzenle',
            style: SwanType.h3(ink)),
        content: TextField(
          controller: ctrl,
          minLines: 3,
          maxLines: 8,
          autofocus: true,
          style: SwanType.bodySm(ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet', style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref
          .read(socialServiceProvider)
          .updatePost(widget.post.id, ctrl.text);
      ref.invalidate(feedProvider);
      ref.invalidate(discoverProvider);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gönderi güncellendi'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Güncellenemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Gönderiyi sil', style: SwanType.h3(ink)),
        content: Text('Bu gönderi kalıcı olarak silinecek.',
            style: SwanType.bodySm(SwanColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style:
                    SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil',
                style: SwanType.bodySm(const Color(0xFFF43F5E), w: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (yes != true) return;

    try {
      await ref.read(socialServiceProvider).deletePost(widget.post.id);
      ref.invalidate(feedProvider);
      ref.invalidate(discoverProvider);
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gönderi silindi'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  void _openProfile() {
    final p = widget.post;
    if (p.isClubPost) {
      Navigator.pushNamed(context, '/kulup-profil', arguments: p.clubId);
    } else {
      Navigator.pushNamed(context, '/profil', arguments: p.authorId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final p = widget.post;

    // Brief §5: "Her postu ayrı büyük beyaz kutuya koyma." Kart kabuğu
    // (yüzey + border + 20 radius) kalktı; gönderiler zeminin üstünde ince
    // bir ayırıcıyla akıyor, medya tam genişlikte oturuyor.
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 10),
            child: Row(children: [
              GestureDetector(
                onTap: _openProfile,
                child: SocialAvatar(
                  initials: p.initials,
                  imageUrl: p.authorAvatarUrl,
                  size: 42,
                  gradientIndex: p.displayName.length % 4,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: GestureDetector(
                  onTap: _openProfile,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(p.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.bodySm(ink, w: FontWeight.w800)),
                        ),
                        if (p.isClubPost) ...[
                          const SizedBox(width: 4),
                          const VerifiedBadge(size: 14),
                        ],
                      ]),
                      const SizedBox(height: 1),
                      Text(
                        p.isClubPost
                            ? 'Kulüp · ${shortAgo(p.createdAt)}'
                            : shortAgo(p.createdAt),
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (p.isNews)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCoral.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child:
                      Text('HABER', style: SwanType.caption(kCoral, w: FontWeight.w800)),
                ),
              // Menü: kendi gönderinde sil, başkasınınkinde şikayet/engelle
              GestureDetector(
                onTap: _openMenu,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.more_horiz_rounded,
                      size: 20, color: SwanColors.textSecondary),
                ),
              ),
            ]),
          ),

          // Metin
          if (p.body.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, p.imageUrl == null ? 12 : 10),
              child: Text(p.body,
                  style: SwanType.bodySm(ink)
                      .copyWith(height: 1.45)),
            ),

          // Görsel — kendi oranında, 4:5 ile 1.91:1 arasına sıkıştırılmış.
          // Kart kabuğu kalktığı için artık tam genişlik: brief §5
          // "içeriklerin ekranı doldurması".
          if (p.imageUrl != null)
            RatioImage(image: NetworkImage(p.imageUrl!)),

          // Eylemler
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
            child: Row(children: [
              _action(
                icon: _liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _liked ? const Color(0xFFF43F5E) : null,
                label: _likes > 0 ? compactCount(_likes) : 'Beğen',
                onTap: _toggleLike,
              ),
              _action(
                icon: Icons.mode_comment_outlined,
                label: _comments > 0 ? compactCount(_comments) : 'Yorum',
                onTap: _openComments,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ??
        (isDark ? const Color(0xFF8FA0B8) : SwanColors.textSecondary);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Icon(icon, size: 21, color: c),
          const SizedBox(width: 6),
          Text(label, style: SwanType.caption(c, w: FontWeight.w700)),
        ]),
      ),
    );
  }
}
