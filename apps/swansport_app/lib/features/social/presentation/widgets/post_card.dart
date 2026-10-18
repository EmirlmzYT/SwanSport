import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../comments_sheet.dart';
import 'report_sheet.dart';
import 'social_widgets.dart';
import 'athletic_highlights.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/widgets/shared_content_card.dart';
import '../saved_posts_screen.dart';

/// Akıştaki tek gönderi kartı — Instagram benzeri.
class PostCard extends ConsumerStatefulWidget {
  const PostCard({super.key, required this.post, this.onChanged});

  final PostRow post;
  final VoidCallback? onChanged;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with SingleTickerProviderStateMixin {
  /// Beğeni "pop"u — brief §21: "like → micro scale animation".
  /// 1.0 → 1.3 → 1.0, tek seferlik ve kısa. Uzun ya da yaylı bir animasyon
  /// akışta her beğenide göze batardı.
  late final AnimationController _likePop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _likeScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _likePop, curve: Curves.easeOut));

  late bool _liked = widget.post.likedByMe;
  late int _likes = widget.post.likeCount;
  late int _comments = widget.post.commentCount;
  bool _busy = false;

  @override
  void dispose() {
    _likePop.dispose();
    super.dispose();
  }

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
    // Yalnızca beğenirken; beğeniyi geri alırken pop tuhaf duruyor.
    if (next && !MediaQuery.disableAnimationsOf(context)) {
      _likePop.forward(from: 0);
    }
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

  void _likeOnDoubleTap() {
    if (!_liked && !_busy) _toggleLike();
  }

  Future<void> _openComments() async {
    await showCommentsSheet(context, widget.post.id);
    if (!mounted) return;
    try {
      ref.invalidate(postCommentsProvider(widget.post.id));
      final comments =
          await ref.read(postCommentsProvider(widget.post.id).future);
      if (mounted) setState(() => _comments = comments.length);
    } catch (_) {
      // Akış kartındaki son bilinen sayı korunur.
    }
  }

  /// Gönderi menüsü — sahibine silme, diğerlerine şikayet ve engelleme.
  Future<void> _openMenu() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final isMine =
        widget.post.authorId == Supabase.instance.client.auth.currentUser?.id;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: surf.withValues(alpha: 0),
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
        ),
        padding: const EdgeInsets.fromLTRB(
            SwanSpace.md, SwanSpace.lg, SwanSpace.md, SwanSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.swan.line,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
          ),
          const SizedBox(height: SwanSpace.lg),
          if (isMine) ...[
            // Sabitleme sunucuda doğrulanıyor: yalnızca kendi ve yayındaki
            // gönderi. Taslak sabitlenirse profilde görünen ama kimsenin
            // açamadığı bir kart olurdu.
            _menuItem(ctx, Icons.push_pin_outlined, 'Profilime sabitle', ink,
                () {
              Navigator.pop(ctx);
              _pinPost();
            }),
            _menuItem(ctx, Icons.edit_outlined, 'Gönderiyi düzenle', ink, () {
              Navigator.pop(ctx);
              _editPost();
            }),
            _menuItem(ctx, Icons.delete_outline_rounded, 'Gönderiyi sil',
                context.swan.danger, () {
              Navigator.pop(ctx);
              _confirmDelete();
            }),
          ] else ...[
            _menuItem(
                ctx, Icons.flag_outlined, 'Şikayet et', context.swan.danger,
                () {
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SwanRadius.md)),
    );
  }

  Future<void> _confirmBlock() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.lg)),
        title: Text('Kullanıcıyı engelle', style: SwanType.h3(ink)),
        content: Text(
            '${widget.post.displayName} artık gönderilerini göremeyecek ve '
            'sana mesaj gönderemeyecek. Karşılıklı takip kaldırılır.',
            style: SwanType.bodySm(
                (isDark ? SwanPalette.dark : SwanPalette.light).inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: SwanType.bodySm(
                    (isDark ? SwanPalette.dark : SwanPalette.light).inkMuted,
                    w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Engelle',
                style:
                    SwanType.bodySm(context.swan.danger, w: FontWeight.w800)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kullanıcı engellendi'),
            backgroundColor: context.swan.accent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Engellenemedi: $e'),
            backgroundColor: context.swan.danger));
      }
    }
  }

  /// Gönderi metnini düzenler (görsel değişmez).
  Future<void> _pinPost() async {
    try {
      await ref.read(socialServiceProvider).setPinnedPost(widget.post.id);
      ref.invalidate(socialProfileProvider(widget.post.authorId));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Profiline sabitlendi')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _editPost() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final ctrl = TextEditingController(text: widget.post.body);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.lg)),
        title: Text('Gönderiyi düzenle', style: SwanType.h3(ink)),
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
                style: SwanType.bodySm(
                    (isDark ? SwanPalette.dark : SwanPalette.light).inkMuted,
                    w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Kaydet',
                style:
                    SwanType.bodySm(context.swan.accent, w: FontWeight.w800)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderi güncellendi'),
            backgroundColor: context.swan.accent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Güncellenemedi: $e'),
            backgroundColor: context.swan.danger));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surf,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.lg)),
        title: Text('Gönderiyi sil', style: SwanType.h3(ink)),
        content: Text('Bu gönderi kalıcı olarak silinecek.',
            style: SwanType.bodySm(
                (isDark ? SwanPalette.dark : SwanPalette.light).inkMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: SwanType.bodySm(
                    (isDark ? SwanPalette.dark : SwanPalette.light).inkMuted,
                    w: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Sil',
                style:
                    SwanType.bodySm(context.swan.danger, w: FontWeight.w800)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderi silindi'),
            backgroundColor: context.swan.accent));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Silinemedi: $e'),
            backgroundColor: context.swan.danger));
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
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final p = widget.post;

    // Kenarlıksız yüzey; medya kartın yumuşak kenarlarında kırpılır.
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.swan.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      padding: const EdgeInsets.only(bottom: SwanSpace.sm),
      child: Material(
        color: context.swan.surface.withValues(alpha: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Padding(
              padding: const EdgeInsets.all(SwanSpace.lg),
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
                const SizedBox(width: SwanSpace.md),
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
                                style:
                                    SwanType.bodySm(ink, w: FontWeight.w800)),
                          ),
                          if (p.isClubPost) ...[
                            const SizedBox(width: SwanSpace.xs),
                            const VerifiedBadge(size: 14),
                          ],
                        ]),
                        const SizedBox(height: 1),
                        Text(
                          p.isClubPost
                              ? 'Kulüp · ${shortAgo(p.createdAt)}'
                              : shortAgo(p.createdAt),
                          style: SwanType.caption(
                              (isDark ? SwanPalette.dark : SwanPalette.light)
                                  .inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                if (p.isNews)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.sm, vertical: SwanSpace.xs),
                    decoration: BoxDecoration(
                      color: context.swan.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('HABER',
                        style: SwanType.caption(context.swan.inkMuted,
                            w: FontWeight.w800)),
                  ),
                // Menü: kendi gönderinde sil, başkasınınkinde şikayet/engelle
                GestureDetector(
                  onTap: _openMenu,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: SwanSpace.sm),
                    child: Icon(Icons.more_horiz_rounded,
                        size: 20,
                        color: (isDark ? SwanPalette.dark : SwanPalette.light)
                            .inkMuted),
                  ),
                ),
              ]),
            ),

            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _likeOnDoubleTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Yalnız açık sportif beyanlar; resmi doğrulama değildir.
                  if (!p.isNews) AthleticHighlights(body: p.body),
                  if (p.body.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.md),
                      child: Text(p.body,
                          style: SwanType.bodySm(ink).copyWith(height: 1.45)),
                    ),
                  if (p.imageUrl != null)
                    RatioImage(image: NetworkImage(p.imageUrl!)),
                  if (p.sourcePostId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.md),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(SwanSpace.md),
                        decoration: BoxDecoration(
                          color: context.swan.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.isRepost
                                  ? 'Yeniden paylaşıldı'
                                  : 'Alıntılanan gönderi',
                              style: SwanType.caption(context.swan.inkMuted),
                            ),
                            const SizedBox(height: SwanSpace.xs),
                            if (p.sourcePost == null)
                              Text('Bu gönderi artık kullanılamıyor.',
                                  style: SwanType.bodySm(context.swan.inkMuted))
                            else ...[
                              Text(p.sourcePost!.displayName,
                                  style: SwanType.bodySm(context.swan.ink,
                                      w: FontWeight.w700)),
                              if (p.sourcePost!.body.trim().isNotEmpty)
                                Text(p.sourcePost!.body,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: SwanType.bodySm(context.swan.ink)),
                              if (p.sourcePost!.imageUrl != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: SwanSpace.sm),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(SwanRadius.sm),
                                    child: Image.network(
                                      p.sourcePost!.imageUrl!,
                                      width: 96,
                                      height: 96,
                                      cacheWidth: (96 *
                                              MediaQuery.devicePixelRatioOf(
                                                  context))
                                          .round(),
                                      cacheHeight: (96 *
                                              MediaQuery.devicePixelRatioOf(
                                                  context))
                                          .round(),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Eylemler
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.sm, SwanSpace.sm, SwanSpace.md, SwanSpace.sm),
              child: Row(children: [
                _action(
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? context.swan.danger : null,
                  label: _likes > 0 ? compactCount(_likes) : '',
                  tooltip: 'Beğen',
                  onTap: _toggleLike,
                  scale: _likeScale,
                ),
                _action(
                  icon: Icons.mode_comment_outlined,
                  label: _comments > 0 ? compactCount(_comments) : '',
                  tooltip: 'Yorumlar',
                  onTap: _openComments,
                ),
                _action(
                  icon: Icons.repeat_rounded,
                  label: '',
                  tooltip: 'Alıntıla veya yeniden paylaş',
                  onTap: () => showRepostSheet(
                    context,
                    ref,
                    postId: widget.post.id,
                    authorName: widget.post.displayName,
                    preview: widget.post.body.isEmpty
                        ? '(görsel gönderi)'
                        : widget.post.body,
                  ),
                ),
                _action(
                  icon: Icons.send_outlined,
                  label: '',
                  tooltip: 'Mesajla gönder',
                  onTap: () => showShareSheet(context,
                      kind: ShareKind.post, id: widget.post.id),
                ),
                const Spacer(),
                // Kaydetme kişisel bir yer imi: gönderi sahibine bildirim
                // gitmiyor ve sayı gösterilmiyor. Sayı göstermek onu kamusal
                // bir beğeniye çevirirdi.
                _action(
                  icon: _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  label: '',
                  tooltip: 'Kaydet',
                  onTap: _toggleSaved,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Kaydedildi mi. İyimser: dokunuşta anında değişiyor, istek başarısız
  /// olursa geri alınıyor.
  bool _saved = false;

  Future<void> _toggleSaved() async {
    final before = _saved;
    setState(() => _saved = !before);
    try {
      final now = await ref
          .read(socialShareServiceProvider)
          .toggleSaved(widget.post.id);
      if (mounted && now != _saved) setState(() => _saved = now);
    } catch (_) {
      if (mounted) setState(() => _saved = before);
    }
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? tooltip,
    Color? color,
    Animation<double>? scale,
  }) {
    final c = color ?? context.swan.inkMuted;
    return Tooltip(
        message: tooltip ?? label,
        child: Semantics(
            button: true,
            label: tooltip ?? label,
            child: InkWell(
              borderRadius: BorderRadius.circular(SwanRadius.md),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: SwanSpace.md, vertical: SwanSpace.sm),
                child: Row(children: [
                  scale == null
                      ? Icon(icon, size: 21, color: c)
                      : ScaleTransition(
                          scale: scale, child: Icon(icon, size: 21, color: c)),
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: SwanSpace.sm),
                    Text(label, style: SwanType.caption(c, w: FontWeight.w700)),
                  ],
                ]),
              ),
            )));
  }
}
