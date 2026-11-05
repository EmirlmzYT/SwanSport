import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_picker_sheet.dart';
import '../../../app/widgets/tag_composer.dart';
import '../../../app/widgets/friendly_error.dart';

/// Gönderi oluşturma sayfasını açar. Paylaşım yapıldıysa true döner.
Future<bool?> showPostComposer(BuildContext context,
    {bool startWithImage = false}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => PostComposerSheet(startWithImage: startWithImage),
  );
}

/// Gönderi oluşturma yüzeyi. [initialMedia] yalnızca yerel görsel doğrulama
/// fixture'larının gerçek seçici eklentisini açmadan fotoğraf durumunu kurması
/// içindir; üretim çağrısı her zaman boş başlar.
class PostComposerSheet extends ConsumerStatefulWidget {
  const PostComposerSheet({
    super.key,
    this.startWithImage = false,
    this.initialMedia = const [],
  });

  /// Ana akıştaki fotoğraf kısayolu, besteci açılır açılmaz seçiciyi başlatır.
  final bool startWithImage;
  final List<PickedMedia> initialMedia;

  @override
  ConsumerState<PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<PostComposerSheet> {
  final _ctrl = TextEditingController();
  final _focusNode = FocusNode();

  /// Seçilen görseller, sırasıyla. En fazla 8 — sınır hem burada hem
  /// veritabanı tetikleyicisinde (0062).
  late final List<PickedMedia> _media;

  /// Gönderiyi kim görecek. Boş bırakılırsa sunucu karar veriyor: reşit
  /// olmayan hesaplarda tetikleyici `public` yerine `followers` yazıyor.
  PostVisibility? _visibility;

  /// Seçilen etiketler. Metin ile kimlik ayrı: kullanıcı adı yazılıyor,
  /// veritabanına UUID gidiyor.
  final _tags = TagState();

  // null = yetkiler yüklenince güvenli varsayılanı seç. İki kimlik de varsa
  // kişisel kimlik kazanır; yalnız kulüp yetkisi varsa kulüp seçilir.
  bool? _asClub;
  bool _busy = false;
  bool _picking = false;
  bool _postCreated = false;

  static const _maxMedia = 8;

  @override
  void initState() {
    super.initState();
    _media = [...widget.initialMedia.take(_maxMedia)];
    if (widget.startWithImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickImage();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
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
    } catch (error) {
      if (mounted) {
        _snack(
          friendlyErrorMessage(
            error,
            defaultMessage: 'Fotoğraflar seçilemedi. Tekrar deneyin.',
          ),
          context.swan.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _share(String? clubId) async {
    if (_busy || _picking || _postCreated) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty && _media.isEmpty) {
      _snack('Bir şeyler yaz ya da görsel ekle', context.swan.warning);
      return;
    }
    // Gönderim süresince tüm alanlar kilitli olsa da servis çağrısı için tek
    // ve tutarlı bir anlık kopya kullanılır.
    final submittedClubId = clubId;
    final submittedVisibility = _visibility;
    final submittedMedia = List<PickedMedia>.unmodifiable(_media);
    final submittedMentions = List<String>.unmodifiable(
      _tags.mentionsIn(text),
    );
    final submittedHashtags = List<String>.unmodifiable(
      TagState.hashtagsIn(text),
    );
    setState(() => _busy = true);
    try {
      final postId = await ref.read(socialServiceProvider).createPost(
            body: text,
            clubId: submittedClubId,
            images: submittedMedia,
            visibility: submittedClubId != null || submittedVisibility == null
                ? null
                : visibilityKey(submittedVisibility),
          );
      _postCreated = true;

      // Etiketler ayrı çağrı.
      String? partialMessage;
      if (submittedMentions.isNotEmpty || submittedHashtags.isNotEmpty) {
        try {
          final done = await ref.read(socialShareServiceProvider).setTags(
                postId,
                mentions: submittedMentions,
                hashtags: submittedHashtags,
              );
          if (done < submittedMentions.length) {
            partialMessage =
                'Gönderi paylaşıldı; ${submittedMentions.length - done} kişi etiketlenemedi.';
          }
        } catch (e) {
          partialMessage = friendlyErrorMessage(
            e,
            defaultMessage: 'Gönderi paylaşıldı, etiketler eklenemedi.',
          );
        }
      }

      ref.invalidate(feedProvider);
      ref.invalidate(discoverProvider);
      if (submittedClubId != null) {
        ref.invalidate(clubPostsProvider(submittedClubId));
      }
      final myId = ref.read(currentProfileProvider).valueOrNull?.id;
      if (myId != null) {
        ref.invalidate(authorPostsProvider(myId));
      }

      if (!mounted) return;
      if (partialMessage != null) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: Icon(Icons.info_outline_rounded, color: context.swan.warning),
            title: const Text('Gönderi paylaşıldı'),
            content: Text(partialMessage!),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted && !_postCreated) {
        _snack(
            friendlyErrorMessage(e,
                defaultMessage:
                    'Gönderi paylaşılamadı. Lütfen tekrar deneyin.'),
            context.swan.danger);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _hasDraft => _ctrl.text.trim().isNotEmpty || _media.isNotEmpty;

  Future<void> _requestClose() async {
    if (_busy || _postCreated) return;
    if (!_hasDraft) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gönderiden vazgeçilsin mi?'),
        content: const Text('Yazdıkların ve seçtiğin fotoğraflar kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Düzenlemeye devam et'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  void _insertToken(String token) {
    final value = _ctrl.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final start = selection.start.clamp(0, value.text.length);
    final end = selection.end.clamp(0, value.text.length);
    final before = value.text.substring(0, start);
    final after = value.text.substring(end);
    final prefix = before.isEmpty || RegExp(r'\s$').hasMatch(before) ? '' : ' ';
    final suffix = after.isEmpty || RegExp(r'^\s').hasMatch(after) ? '' : ' ';
    final inserted = '$prefix$token$suffix';
    _ctrl.value = TextEditingValue(
      text: '$before$inserted$after',
      selection: TextSelection.collapsed(offset: start + inserted.length),
    );
    _focusNode.requestFocus();
    setState(() {});
  }

  void _moveMedia(int from, int to) {
    if (_busy || from == to || to < 0 || to >= _media.length) return;
    setState(() {
      final item = _media.removeAt(from);
      _media.insert(to, item);
    });
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final clubAsync = ref.watch(activeClubProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final credentialsAsync = ref.watch(myCredentialsProvider);
    final club = clubAsync.valueOrNull;
    final access = ref.watch(swanAccessProvider);
    final profile = profileAsync.valueOrNull;
    final creds = credentialsAsync.valueOrNull ?? const [];
    final identityLoading = clubAsync.isLoading ||
        profileAsync.isLoading ||
        credentialsAsync.isLoading;
    final canPostPersonally = creds.any((c) => c.status == 'approved');
    final canPostAsClub = club != null && access.canPublishClubPosts;
    final effectiveAsClub = canPostAsClub &&
        ((_asClub ?? (!canPostPersonally && canPostAsClub)) ||
            !canPostPersonally);
    final canShare = canPostAsClub || canPostPersonally;
    final hasContent = _ctrl.text.trim().isNotEmpty || _media.isNotEmpty;

    final displayName =
        effectiveAsClub ? club.name : (profile?.fullName ?? 'Kullanıcı');

    return PopScope(
      canPop: !_hasDraft && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.sizeOf(context).height * .96,
          ),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Gönderi oluşturmayı kapat',
                      onPressed: _busy ? null : _requestClose,
                      icon: const Icon(Icons.close_rounded),
                    ),
                    Expanded(
                      child: Text(
                        'Yeni gönderi',
                        style: SwanType.h3(c.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FilledButton(
                      onPressed: (_busy ||
                              _picking ||
                              identityLoading ||
                              !canShare ||
                              !hasContent ||
                              _postCreated)
                          ? null
                          : () => _share(effectiveAsClub ? club.id : null),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _visibility == PostVisibility.privateDraft &&
                                      !effectiveAsClub
                                  ? 'Taslağı kaydet'
                                  : 'Paylaş',
                            ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: c.line.withValues(alpha: .6)),

              // 3. İçerik Alanı
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (identityLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (!canShare)
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

                      if (!identityLoading)
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
                                style:
                                    SwanType.body(c.accent, w: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: SwanType.body(c.ink,
                                        w: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  InkWell(
                                    onTap: _busy || effectiveAsClub
                                        ? null
                                        : () =>
                                            _showVisibilityPicker(context, c),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: c.surfaceAlt,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color:
                                                c.line.withValues(alpha: .8)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _visibility ==
                                                    PostVisibility.followers
                                                ? Icons.people_alt_rounded
                                                : _visibility ==
                                                        PostVisibility
                                                            .privateDraft
                                                    ? Icons.lock_outline_rounded
                                                    : Icons.public_rounded,
                                            size: 13,
                                            color: c.accent,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              effectiveAsClub
                                                  ? 'Kulüp gönderisi'
                                                  : (_visibility != null
                                                      ? visibilityLabel(
                                                          _visibility!)
                                                      : 'Varsayılan görünürlük'),
                                              style: SwanType.caption(
                                                c.ink,
                                                w: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          if (!effectiveAsClub)
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 14,
                                              color: c.inkMuted,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canPostAsClub && canPostPersonally)
                              TextButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _showIdentityPicker(
                                          context,
                                          c,
                                          profileName: profile?.fullName ??
                                              'Kişisel profil',
                                          clubName: club.name,
                                          effectiveAsClub: effectiveAsClub,
                                        ),
                                icon: const Icon(Icons.swap_horiz_rounded),
                                label: const Text('Değiştir'),
                              ),
                          ],
                        ),

                      const SizedBox(height: 14),

                      // Instagram Tipi Temiz Metin Alanı
                      TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        enabled: !_busy,
                        minLines: 4,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) => setState(() {}),
                        style: SwanType.body(c.ink),
                        decoration: InputDecoration(
                          hintText: 'Ne paylaşmak istersin?',
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
                        Row(
                          children: [
                            Text(
                              'Fotoğraflar',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                            ),
                            const Spacer(),
                            Text(
                              '${_media.length}/$_maxMedia',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: _media.length == 1 ? 224 : 164,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _media.length < _maxMedia
                                ? _media.length + 1
                                : _media.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (_, i) {
                              if (i == _media.length) {
                                return InkWell(
                                  onTap: _busy || _picking ? null : _pickImage,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    width: 144,
                                    decoration: BoxDecoration(
                                      color: c.surfaceAlt,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: c.line,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_photo_alternate_rounded,
                                            size: 28, color: c.accent),
                                        const SizedBox(height: 6),
                                        Text('Fotoğraf ekle',
                                            style: SwanType.caption(c.inkMuted,
                                                w: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return _MediaPreviewTile(
                                media: _media[i],
                                index: i,
                                count: _media.length,
                                large: _media.length == 1,
                                enabled: !_busy,
                                onOpen: () => _showMediaPreview(i),
                                onRemove: () =>
                                    setState(() => _media.removeAt(i)),
                                onEarlier:
                                    i == 0 ? null : () => _moveMedia(i, i - 1),
                                onLater: i == _media.length - 1
                                    ? null
                                    : () => _moveMedia(i, i + 1),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: c.line.withValues(alpha: .7)),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _ToolbarIcon(
                                icon: Icons.image_rounded,
                                color: c.accent,
                                tooltip: 'Fotoğraf',
                                label: 'Fotoğraf',
                                badgeCount:
                                    _media.isNotEmpty ? _media.length : null,
                                onTap: _busy ||
                                        _picking ||
                                        _media.length >= _maxMedia
                                    ? null
                                    : _pickImage,
                              ),
                              const SizedBox(width: 10),
                              _ToolbarIcon(
                                icon: Icons.alternate_email_rounded,
                                color: c.accent,
                                tooltip: 'Kişi Etiketle',
                                label: 'Kişi',
                                onTap: _busy ? null : () => _insertToken('@'),
                              ),
                              const SizedBox(width: 10),
                              _ToolbarIcon(
                                icon: Icons.tag_rounded,
                                color: c.accent,
                                tooltip: 'Hashtag Ekle',
                                label: 'Hashtag',
                                onTap: _busy ? null : () => _insertToken('#'),
                              ),
                              if (_picking)
                                const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showIdentityPicker(
    BuildContext context,
    SwanPalette c, {
    required String profileName,
    required String clubName,
    required bool effectiveAsClub,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surface,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kimin adına paylaşılsın?', style: SwanType.h3(c.ink)),
              const SizedBox(height: 12),
              _identityTile(
                c: c,
                icon: Icons.person_rounded,
                title: profileName,
                subtitle: 'Kişisel profil',
                selected: !effectiveAsClub,
                onTap: () {
                  setState(() => _asClub = false);
                  Navigator.pop(sheetContext);
                },
              ),
              _identityTile(
                c: c,
                icon: Icons.groups_rounded,
                title: clubName,
                subtitle: 'Kulüp profili',
                selected: effectiveAsClub,
                onTap: () {
                  setState(() {
                    _asClub = true;
                    _visibility = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identityTile({
    required SwanPalette c,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: CircleAvatar(
        backgroundColor: c.surfaceAlt,
        foregroundColor: c.accent,
        child: Icon(icon),
      ),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing:
          selected ? Icon(Icons.check_circle_rounded, color: c.accent) : null,
    );
  }

  Future<void> _showMediaPreview(int index) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.memory(
                      _media[index].bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'Fotoğraf önizlenemedi',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  tooltip: 'Önizlemeyi kapat',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
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
                  icon: Icons.shield_outlined,
                  title: 'Varsayılan görünürlük',
                  subtitle:
                      'Hesap güvenliği ve yaş kurallarına göre sunucu belirler',
                  selected: _visibility == null,
                  onTap: () {
                    setState(() => _visibility = null);
                    Navigator.pop(ctx);
                  },
                  c: c,
                ),
                _visibilityTile(
                  icon: Icons.public_rounded,
                  title: 'Herkese Açık',
                  subtitle:
                      'Tüm SwanSport sporcuları ve keşfet akışı görebilir',
                  selected: _visibility == PostVisibility.public,
                  onTap: () {
                    setState(() => _visibility = PostVisibility.public);
                    Navigator.pop(ctx);
                  },
                  c: c,
                ),
                _visibilityTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Sadece Takipçiler',
                  subtitle: 'Seni takip eden hesaplar görebilir',
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
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final String label;
  final VoidCallback? onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TextButton.icon(
            onPressed: onTap,
            icon: Icon(icon, color: onTap == null ? null : color, size: 20),
            label: Text(label),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 44),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          if (badgeCount != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  const _MediaPreviewTile({
    required this.media,
    required this.index,
    required this.count,
    required this.large,
    required this.enabled,
    required this.onOpen,
    required this.onRemove,
    required this.onEarlier,
    required this.onLater,
  });

  final PickedMedia media;
  final int index;
  final int count;
  final bool large;
  final bool enabled;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  final VoidCallback? onEarlier;
  final VoidCallback? onLater;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final width = large ? 260.0 : 164.0;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: '${index + 1}. fotoğrafı tam göster',
                    child: InkWell(
                      onTap: onOpen,
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          media.bytes,
                          width: width,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: c.surfaceAlt,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: c.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filled(
                    tooltip: 'Fotoğrafı kaldır',
                    onPressed: enabled ? onRemove : null,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .68),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: Text(
                        '${index + 1}/$count',
                        style:
                            SwanType.caption(Colors.white, w: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (count > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Fotoğrafı öne taşı',
                  onPressed: enabled ? onEarlier : null,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                IconButton(
                  tooltip: 'Fotoğrafı arkaya taşı',
                  onPressed: enabled ? onLater : null,
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
