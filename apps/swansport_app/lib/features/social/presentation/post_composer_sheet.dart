import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_picker_sheet.dart';
import '../../../app/widgets/tag_composer.dart';

/// Gönderi oluşturma sayfasını açar. Paylaşım yapıldıysa true döner.
Future<bool?> showPostComposer(BuildContext context,
    {bool startWithImage = false}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PostComposerSheet(startWithImage: startWithImage),
  );
}

class _PostComposerSheet extends ConsumerStatefulWidget {
  const _PostComposerSheet({this.startWithImage = false});

  /// Ana akıştaki fotoğraf kısayolu, besteci açılır açılmaz seçiciyi başlatır.
  final bool startWithImage;

  @override
  ConsumerState<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<_PostComposerSheet> {
  final _ctrl = TextEditingController();

  /// Seçilen görseller, sırasıyla. En fazla 8 — sınır hem burada hem
  /// veritabanı tetikleyicisinde (0062).
  final List<PickedMedia> _media = [];

  /// Gönderiyi kim görecek. Boş bırakılırsa sunucu karar veriyor: reşit
  /// olmayan hesaplarda tetikleyici `public` yerine `followers` yazıyor.
  PostVisibility? _visibility;

  /// Seçilen etiketler. Metin ile kimlik ayrı: kullanıcı adı yazılıyor,
  /// veritabanına UUID gidiyor.
  final _tags = TagState();

  bool _asClub = true;
  bool _busy = false;
  bool _picking = false;

  static const _maxMedia = 8;

  @override
  void initState() {
    super.initState();
    if (widget.startWithImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickImage();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_busy || _picking || _media.length >= _maxMedia) return;
    setState(() => _picking = true);
    try {
      final images = await showImagePickerSheet(context,
          title: 'Gönderiye fotoğraf ekle', limit: _maxMedia - _media.length);
      if (!mounted) return;
      setState(() => _media.addAll(images
          .map((image) => PickedMedia(bytes: image.bytes, name: image.name))));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _share(String? clubId) async {
    if (_busy || _picking) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty && _media.isEmpty) {
      _snack('Bir şeyler yaz ya da görsel ekle', SwanPalette.light.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final postId = await ref.read(socialServiceProvider).createPost(
            body: text,
            clubId: clubId,
            images: _media,
            visibility: clubId != null || _visibility == null
                ? null
                : visibilityKey(_visibility!),
          );

      // Etiketler ayrı çağrı.
      final wanted = _tags.mentionsIn(text);
      final tagList = TagState.hashtagsIn(text);
      if (wanted.isNotEmpty || tagList.isNotEmpty) {
        try {
          final done = await ref
              .read(socialShareServiceProvider)
              .setTags(postId, mentions: wanted, hashtags: tagList);
          if (done < wanted.length && mounted) {
            _snack('${wanted.length - done} kişi etiketlenemedi',
                SwanPalette.light.warning);
          }
        } catch (e) {
          if (mounted) {
            _snack('Gönderi paylaşıldı, etiketler eklenemedi: $e',
                SwanPalette.light.warning);
          }
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Paylaşılamadı: $e', SwanPalette.light.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];
    final canPostPersonally = creds.any((c) => c.status == 'approved');
    final canPostAsClub = club != null && access.canPublishClubPosts;
    final effectiveAsClub = canPostAsClub && (_asClub || !canPostPersonally);
    final canShare = canPostAsClub || canPostPersonally;
    final hasContent = _ctrl.text.trim().isNotEmpty || _media.isNotEmpty;

    final displayName =
        effectiveAsClub ? club.name : (profile?.fullName ?? 'Kullanıcı');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .94,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Üst Tutamaç (Instagram drag bar)
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: c.inkMuted.withValues(alpha: .3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Instagram-Style Header: Vazgeç | Yeni Gönderi | Paylaş
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _busy ? null : () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Vazgeç',
                      style: SwanType.body(c.inkMuted),
                    ),
                  ),
                ),
                Text(
                  'Yeni Gönderi',
                  style: SwanType.h3(c.ink),
                ),
                GestureDetector(
                  onTap: (_busy || _picking || !canShare || !hasContent)
                      ? null
                      : () => _share(effectiveAsClub ? club.id : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: hasContent && canShare && !_busy
                          ? c.accent
                          : c.accent.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: c.surface,
                            ),
                          )
                        : Text(
                            'Paylaş',
                            style: SwanType.body(
                              hasContent && canShare
                                  ? Colors.white
                                  : Colors.white70,
                              w: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.line.withValues(alpha: .6)),

          // 3. İçerik Alanı
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 12, 16, 20 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!canShare)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: c.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Paylaşım yapabilmek için onaylı sporcu/antrenör belgesi veya kulüp yetkisi gerekiyor.',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Profil Başlığı & Kimin Adına Paylaşıldığı
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: c.accent.withValues(alpha: .15),
                        child: Text(
                          effectiveAsClub
                              ? (club.name.isNotEmpty
                                  ? club.name[0].toUpperCase()
                                  : 'K')
                              : (profile?.initials ?? 'S'),
                          style: SwanType.body(c.accent, w: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: SwanType.body(c.ink, w: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            // Görünürlük Seçim Butonu (Instagram "Hedef Kitle" hapı gibi)
                            InkWell(
                              onTap: _busy
                                  ? null
                                  : () => _showVisibilityPicker(context, c),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: c.line.withValues(alpha: .8)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _visibility == PostVisibility.followers
                                          ? Icons.people_alt_rounded
                                          : _visibility ==
                                                  PostVisibility.privateDraft
                                              ? Icons.lock_outline_rounded
                                              : Icons.public_rounded,
                                      size: 13,
                                      color: c.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      effectiveAsClub
                                          ? 'Kulüp Akışı'
                                          : (_visibility != null
                                              ? visibilityLabel(_visibility!)
                                              : 'Herkese Açık'),
                                      style: SwanType.caption(c.ink,
                                          w: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        size: 14, color: c.inkMuted),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kulüp adına / Kişisel geçiş switch ikonu
                      if (canPostAsClub && canPostPersonally)
                        ActionChip(
                          avatar: Icon(
                            effectiveAsClub
                                ? Icons.business_center_rounded
                                : Icons.person_outline_rounded,
                            size: 16,
                            color: c.accent,
                          ),
                          label: Text(
                            effectiveAsClub ? 'Kulüp' : 'Kişisel',
                            style: SwanType.caption(c.ink, w: FontWeight.w700),
                          ),
                          backgroundColor: c.surfaceAlt,
                          side: BorderSide(color: c.line),
                          onPressed: _busy
                              ? null
                              : () => setState(() => _asClub = !_asClub),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Instagram Tipi Temiz Metin Alanı
                  TextField(
                    controller: _ctrl,
                    enabled: !_busy,
                    minLines: 4,
                    maxLines: 10,
                    onChanged: (_) => setState(() {}),
                    style: SwanType.body(c.ink),
                    decoration: InputDecoration(
                      hintText:
                          'Aklından ne geçiyor? Antrenmanını, maçını veya anını paylaş...',
                      hintStyle:
                          SwanType.body(c.inkMuted.withValues(alpha: .7)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),

                  // Tag & Mention önerileri
                  TagSuggestions(
                    controller: _ctrl,
                    tags: _tags,
                    onChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  // Instagram Tarzı Seçilen Medya Galerisi / Grid
                  if (_media.isNotEmpty) ...[
                    SizedBox(
                      height: 140,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _media.length < _maxMedia
                            ? _media.length + 1
                            : _media.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          if (i == _media.length) {
                            return InkWell(
                              onTap: _busy || _picking ? null : _pickImage,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 140,
                                decoration: BoxDecoration(
                                  color: c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: c.line,
                                    style: BorderStyle.solid,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_rounded,
                                        size: 28, color: c.accent),
                                    const SizedBox(height: 6),
                                    Text('Daha Fazla Ekle',
                                        style: SwanType.caption(c.inkMuted,
                                            w: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  _media[i].bytes,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: GestureDetector(
                                  onTap: _busy
                                      ? null
                                      : () =>
                                          setState(() => _media.removeAt(i)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: .65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${i + 1}/${_media.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Instagram Style Hızlı Eylem Çubuğu
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: c.line.withValues(alpha: .7)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Gönderine Ekle:',
                          style:
                              SwanType.caption(c.inkMuted, w: FontWeight.w700),
                        ),
                        const Spacer(),
                        _ToolbarIcon(
                          icon: Icons.image_rounded,
                          color: Colors.green,
                          tooltip: 'Fotoğraf / Video',
                          badgeCount: _media.isNotEmpty ? _media.length : null,
                          onTap: _busy || _picking || _media.length >= _maxMedia
                              ? null
                              : _pickImage,
                        ),
                        const SizedBox(width: 10),
                        _ToolbarIcon(
                          icon: Icons.alternate_email_rounded,
                          color: Colors.blueAccent,
                          tooltip: 'Kişi Etiketle',
                          onTap: () {
                            _ctrl.text = '${_ctrl.text}@';
                            _ctrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _ctrl.text.length));
                            setState(() {});
                          },
                        ),
                        const SizedBox(width: 10),
                        _ToolbarIcon(
                          icon: Icons.tag_rounded,
                          color: Colors.orangeAccent,
                          tooltip: 'Hashtag Ekle',
                          onTap: () {
                            _ctrl.text = '${_ctrl.text}#';
                            _ctrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _ctrl.text.length));
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVisibilityPicker(BuildContext context, SwanPalette c) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gönderi Hedef Kitlesi', style: SwanType.h3(c.ink)),
                const SizedBox(height: 6),
                Text('Gönderinizi kimlerin görebileceğini belirleyin.',
                    style: SwanType.caption(c.inkMuted)),
                const SizedBox(height: 16),
                _visibilityTile(
                  icon: Icons.public_rounded,
                  title: 'Herkese Açık',
                  subtitle:
                      'Tüm SwanSport sporcuları ve keşfet akışı görebilir',
                  selected: _visibility == PostVisibility.public ||
                      _visibility == null,
                  onTap: () {
                    setState(() => _visibility = PostVisibility.public);
                    Navigator.pop(ctx);
                  },
                  c: c,
                ),
                _visibilityTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Sadece Takipçiler',
                  subtitle: 'Yalnızca seni onaylayan takipçilerin görebilir',
                  selected: _visibility == PostVisibility.followers,
                  onTap: () {
                    setState(() => _visibility = PostVisibility.followers);
                    Navigator.pop(ctx);
                  },
                  c: c,
                ),
                _visibilityTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Yalnızca Ben (Taslak)',
                  subtitle: 'Profilinde gizli kalır, sadece sen görebilirsin',
                  selected: _visibility == PostVisibility.privateDraft,
                  onTap: () {
                    setState(() => _visibility = PostVisibility.privateDraft);
                    Navigator.pop(ctx);
                  },
                  c: c,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _visibilityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required SwanPalette c,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    selected ? c.accent.withValues(alpha: .15) : c.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child:
                  Icon(icon, color: selected ? c.accent : c.inkMuted, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.body(c.ink, w: FontWeight.w700)),
                  Text(subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: c.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            if (badgeCount != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
