import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Kaydedilen gönderiler.
///
/// **Tamamen kişiye özel.** Gönderi sahibine bildirim gitmiyor, sayı
/// gösterilmiyor ve kimin kaydettiği hiçbir yerde görünmüyor. Sayı
/// göstermek kaydetmeyi kişisel bir yer imi olmaktan çıkarıp kamusal bir
/// beğeniye çevirirdi.
///
/// Sonradan silinen ya da sana kapanan gönderi listede **görünmüyor**: kayıt
/// duruyor ama içerik sızmıyor (`my_saved_posts` içinde `can_view_post`
/// süzgeci var).
class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final saved = ref.watch(savedPostsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md,
                    SwanSpace.lg, SwanSpace.md),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Kaydedilenler', style: SwanType.h2(c.ink)),
                ]),
              ),
              Expanded(
                child: saved.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) => list.isEmpty
                      ? premiumEmpty(
                          context,
                          icon: Icons.bookmark_border_rounded,
                          title: 'Henüz kaydedilen yok',
                          subtitle: 'Bir gönderinin sağ altındaki yer imi '
                              'simgesine dokunarak buraya ekleyebilirsin. '
                              'Kaydettiklerini yalnızca sen görürsün.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              SwanSpace.lg, 0, SwanSpace.lg, 132),
                          itemCount: list.length,
                          itemBuilder: (_, i) =>
                              _SavedTile(post: list[i]),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _SavedTile extends ConsumerStatefulWidget {
  const _SavedTile({required this.post});

  final SavedPost post;

  @override
  ConsumerState<_SavedTile> createState() => _SavedTileState();
}

class _SavedTileState extends ConsumerState<_SavedTile> {
  bool _busy = false;

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(socialShareServiceProvider)
          .toggleSaved(widget.post.postId);
      ref.invalidate(savedPostsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final p = widget.post;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.md),
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.author,
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                p.body.isEmpty ? '(görsel gönderi)' : p.body,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: SwanType.bodySm(c.ink),
              ),
              const SizedBox(height: SwanSpace.xs),
              Text(fmtDate(p.savedAt), style: SwanType.caption(c.inkMuted)),
            ],
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        if (_busy)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          GestureDetector(
            onTap: _remove,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.bookmark_rounded, size: 20, color: c.accent),
            ),
          ),
      ]),
    );
  }
}

/// Alıntı yazma sayfası.
///
/// Boş bırakılırsa **repost**, doluysa **alıntı**. İkisi ayrı şey: repost bir
/// sinyal, alıntı bir yorum. Sunucu da aynı ayrımı yapıyor — `p_body` boşsa
/// repost.
Future<void> showRepostSheet(
  BuildContext context,
  WidgetRef ref, {
  required String postId,
  required String authorName,
  required String preview,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RepostSheet(
          postId: postId, authorName: authorName, preview: preview),
    );

class _RepostSheet extends ConsumerStatefulWidget {
  const _RepostSheet({
    required this.postId,
    required this.authorName,
    required this.preview,
  });

  final String postId;
  final String authorName;
  final String preview;

  @override
  ConsumerState<_RepostSheet> createState() => _RepostSheetState();
}

class _RepostSheetState extends ConsumerState<_RepostSheet> {
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final quote = _body.text.trim();
    try {
      await ref
          .read(socialShareServiceProvider)
          .repostOrQuote(widget.postId, body: quote.isEmpty ? null : quote);
      ref.invalidate(feedProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(quote.isEmpty
              ? 'Yeniden paylaşıldı'
              : 'Alıntı paylaşıldı')));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        // Sunucunun mesajı anlamlı: "zaten yeniden paylaştın" ya da
        // "yalnızca herkese açık gönderiler". Ham hatayı gizlemiyoruz.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'.replaceFirst('PostgrestException(message: ', '').split(',').first)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final quote = _body.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(quote ? 'Alıntıla' : 'Yeniden paylaş',
                  style: SwanType.h3(c.ink)),
              const Spacer(),
              if (_busy)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.lg),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentFill,
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('Paylaş',
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(height: SwanSpace.md),
            TextField(
              controller: _body,
              maxLines: 4,
              minLines: 2,
              autofocus: true,
              style: SwanType.bodySm(c.ink),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Bir şey ekle (boş bırakırsan sadece paylaşılır)',
                hintStyle: SwanType.bodySm(c.inkMuted),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  borderSide: BorderSide(color: c.line),
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.md),
            // Alıntılanan gönderinin önizlemesi.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                border: Border.all(color: c.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.authorName,
                      style:
                          SwanType.caption(c.inkMuted, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(widget.preview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
