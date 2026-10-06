import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';
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

  static const _maxMedia = 8;

  @override
  void initState() {
    super.initState();
    if (widget.startWithImage) {
      Future.microtask(_pickImage);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_media.length >= _maxMedia) {
      _snack('En fazla $_maxMedia fotoğraf ekleyebilirsin',
          SwanPalette.light.warning);
      return;
    }
    try {
      final picked = await pickImage();
      if (picked == null || !mounted) return;
      setState(() =>
          _media.add(PickedMedia(bytes: picked.bytes, name: picked.name)));
    } catch (e) {
      _snack('Görsel seçilemedi: $e', SwanPalette.light.danger);
    }
  }

  Future<void> _share(String? clubId) async {
    if (_busy) return;
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
    final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];
    final canPostPersonally = creds.any((c) => c.status == 'approved');
    final canPostAsClub = club != null && access.canPublishClubPosts;
    final effectiveAsClub = canPostAsClub && (_asClub || !canPostPersonally);
    final canShare = canPostAsClub || canPostPersonally;
    return SafeArea(
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .92),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        decoration: BoxDecoration(
            color: c.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('Yeni Gönderi', style: SwanType.h3(c.ink))),
            IconButton(
                tooltip: 'Kapat',
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close)),
          ]),
          Flexible(
              child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                if (!canShare)
                  Text(
                      'Paylaşım için onaylanmış sporcu veya antrenör belgesi ya da kulüp yetkisi gerekiyor.',
                      style: SwanType.bodySm(c.inkMuted)),
                if (canPostAsClub && canPostPersonally)
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${club.name} adına paylaş'),
                      value: _asClub,
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _asClub = value)),
                if (canShare) ...[
                  TextField(
                      controller: _ctrl,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 8,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          hintText:
                              'Ne paylaşmak istersin? @kişi veya #etiket ekleyebilirsin.')),
                  TagSuggestions(
                      controller: _ctrl,
                      tags: _tags,
                      onChanged: () => setState(() {})),
                  const SizedBox(height: 12),
                  if (_media.isNotEmpty)
                    SizedBox(
                        height: 132,
                        child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _media.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) => Stack(children: [
                                  Image.memory(_media[i].bytes,
                                      width: 132,
                                      height: 132,
                                      fit: BoxFit.cover),
                                  Positioned(
                                      top: 0,
                                      right: 0,
                                      child: IconButton.filled(
                                          tooltip: 'Fotoğrafı kaldır',
                                          onPressed: _busy
                                              ? null
                                              : () => setState(
                                                  () => _media.removeAt(i)),
                                          icon: const Icon(Icons.close))),
                                ]))),
                  TextButton.icon(
                      onPressed: _busy || _media.length >= _maxMedia
                          ? null
                          : _pickImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label:
                          Text('Fotoğraf ekle (${_media.length}/$_maxMedia)')),
                  if (!effectiveAsClub)
                    DropdownButtonFormField<PostVisibility>(
                        initialValue: _visibility,
                        decoration: const InputDecoration(
                            labelText: 'Görünürlük',
                            hintText: 'Hesabın gizlilik varsayılanı'),
                        items: [
                          for (final visibility in [
                            PostVisibility.public,
                            PostVisibility.followers,
                            PostVisibility.privateDraft
                          ])
                            DropdownMenuItem(
                                value: visibility,
                                child: Text(visibilityLabel(visibility)))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _visibility = value)),
                  const SizedBox(height: 12),
                  Text(
                      effectiveAsClub
                          ? 'Kulüp adına paylaşılacak.'
                          : 'Görünürlüğü seçmezsen hesabının gizlilik varsayılanı uygulanır.',
                      style: SwanType.caption(c.inkMuted)),
                ],
              ]))),
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: _busy || !canShare
                      ? null
                      : () => _share(effectiveAsClub ? club.id : null),
                  child: Text(_busy ? 'Paylaşılıyor…' : 'Paylaş'))),
        ]),
      ),
    );
  }
}
