import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';
import 'widgets/social_widgets.dart';

/// Kaydedilen gönderiler (Stitch Calm Athletic Modernism).
///
/// **Tamamen kişiye özel.** Gönderi sahibine bildirim gitmiyor, sayı
/// gösterilmiyor ve kimin kaydettiği hiçbir yerde görünmüyor.
class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _categoryIndex = 0;

  static const _categories = [
    'Tümü',
    'Antrenman Teknikleri',
    'Duyurular',
    'Beslenme & Kondisyon',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showNewCollectionDialog() {
    final titleCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final c = ctx.swan;
        return AlertDialog(
          backgroundColor: c.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
          title: Text('Yeni Koleksiyon', style: SwanType.h3(c.ink)),
          content: TextField(
            controller: titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Koleksiyon adı (örn. Yay Ayarları)',
              hintStyle: SwanType.bodySm(c.inkMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Vazgeç', style: SwanType.caption(c.inkMuted)),
            ),
            TextButton(
              onPressed: () {
                final name = titleCtrl.text.trim();
                Navigator.pop(ctx);
                if (name.isNotEmpty && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('“$name” koleksiyonu oluşturuldu.'),
                      backgroundColor: c.accent,
                    ),
                  );
                }
              },
              child: Text('Oluştur', style: SwanType.caption(c.accent, w: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final savedAsync = ref.watch(savedPostsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.xs),
                  child: SwanPageHeader(
                    title: 'Kaydedilenler',
                    subtitle: 'Yalnızca senin görebildiğin kişisel arşivin',
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),

                // Top Search and New Collection Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg, vertical: SwanSpace.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: c.inkMuted, size: 19),
                              const SizedBox(width: SwanSpace.xs),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                                  style: SwanType.body(c.ink),
                                  decoration: InputDecoration(
                                    hintText: 'Kaydedilenler içinde ara...',
                                    hintStyle: SwanType.bodySm(c.inkMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              if (_searchCtrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                  child: Icon(Icons.close_rounded, size: 16, color: c.inkMuted),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      InkWell(
                        onTap: _showNewCollectionDialog,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                            border: Border.all(color: c.line),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.bookmark_add_outlined, color: c.accent, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                'Yeni',
                                style: SwanType.caption(c.accent, w: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Pills
                const SizedBox(height: SwanSpace.xs),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: SwanSpace.xs),
                    itemBuilder: (context, i) {
                      final on = _categoryIndex == i;
                      return InkWell(
                        onTap: () => setState(() => _categoryIndex = i),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: on ? c.accentFill : c.surfaceAlt,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _categories[i],
                            style: SwanType.caption(
                              on ? Colors.white : c.inkMuted,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),

                // Content List
                Expanded(
                  child: savedAsync.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      final filtered = list.where((p) {
                        if (_query.isNotEmpty) {
                          final matchBody = p.body.toLowerCase().contains(_query);
                          final matchAuthor = p.author.toLowerCase().contains(_query);
                          if (!matchBody && !matchAuthor) return false;
                        }
                        if (_categoryIndex == 1) {
                          return p.body.toLowerCase().contains('teknik') ||
                              p.body.toLowerCase().contains('antrenman');
                        } else if (_categoryIndex == 2) {
                          return p.body.toLowerCase().contains('duyuru') ||
                              p.body.toLowerCase().contains('seçme');
                        } else if (_categoryIndex == 3) {
                          return p.body.toLowerCase().contains('beslenme') ||
                              p.body.toLowerCase().contains('kondisyon');
                        }
                        return true;
                      }).toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(SwanSpace.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: c.surfaceAlt,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.bookmark_border_rounded, color: c.inkMuted, size: 28),
                                ),
                                const SizedBox(height: SwanSpace.md),
                                Text(
                                  list.isEmpty ? 'Henüz kaydedilen yok' : 'Eşleşen kayıt bulunamadı',
                                  style: SwanType.h3(c.ink),
                                ),
                                const SizedBox(height: SwanSpace.xs),
                                Text(
                                  list.isEmpty
                                      ? 'Bir gönderinin sağ altındaki yer imi simgesine dokunarak buraya ekleyebilirsin. Kaydettiklerini yalnızca sen görürsün.'
                                      : 'Farklı bir arama terimi veya kategori deneyebilirsin.',
                                  textAlign: TextAlign.center,
                                  style: SwanType.caption(c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.xs, SwanSpace.lg, 132),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: SwanSpace.md),
                        itemBuilder: (_, i) => _StitchSavedCard(post: filtered[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _StitchSavedCard extends ConsumerStatefulWidget {
  const _StitchSavedCard({required this.post});

  final SavedPost post;

  @override
  ConsumerState<_StitchSavedCard> createState() => _StitchSavedCardState();
}

class _StitchSavedCardState extends ConsumerState<_StitchSavedCard> {
  bool _busy = false;

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await ref.read(socialShareServiceProvider).toggleSaved(widget.post.postId);
      ref.invalidate(savedPostsProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final p = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Author + Role + Date + Save Toggle
          Row(
            children: [
              SocialAvatar(
                initials: p.author.isNotEmpty ? p.author[0].toUpperCase() : '?',
                size: 38,
                gradientIndex: p.author.length % 4,
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Antrenör',
                            style: SwanType.caption(c.accent, w: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kaydedilme: ${shortAgo(p.savedAt)}',
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                InkWell(
                  onTap: _remove,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bookmark_rounded, size: 20, color: c.accent),
                  ),
                ),
            ],
          ),

          // Optional Image or Media Banner Preview
          if (p.imagePath != null && p.imagePath!.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    p.imagePath!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
          ],

          // Post Body
          const SizedBox(height: SwanSpace.sm),
          Text(
            p.body.isEmpty ? '(görsel gönderi)' : p.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: SwanType.body(c.ink),
          ),

          // Footer meta strip
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 15, color: c.inkMuted),
              const SizedBox(width: 4),
              Text('1.2B', style: SwanType.caption(c.inkMuted)),
              const SizedBox(width: SwanSpace.md),
              Icon(Icons.chat_bubble_outline_rounded, size: 14, color: c.inkMuted),
              const SizedBox(width: 4),
              Text('24', style: SwanType.caption(c.inkMuted)),
              const Spacer(),
              Text(
                'Kişisel Arşiv',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alıntı yazma sayfası.
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
        postId: postId,
        authorName: authorName,
        preview: preview,
      ),
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
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(socialShareServiceProvider).repostOrQuote(
            widget.postId,
            body: _controller.text.trim().isEmpty ? null : _controller.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paylaşıldı')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      ),
      padding: EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.md,
        SwanSpace.lg,
        SwanSpace.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Alıntı Yap', style: SwanType.h3(c.ink)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.authorName, style: SwanType.caption(c.accent, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(widget.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(c.ink)),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          TextField(
            controller: _controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Düşüncelerini ekle (isteğe bağlı)...',
              hintStyle: SwanType.bodySm(c.inkMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          ElevatedButton(
            onPressed: _busy ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accentFill,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.sm)),
            ),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Paylaş', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
