import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import '../../demo/demo_role.dart';
import 'widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Gönderi oluşturma sayfasını açar. Paylaşım yapıldıysa true döner.
Future<bool?> showPostComposer(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _PostComposerSheet(),
  );
}

class _PostComposerSheet extends ConsumerStatefulWidget {
  const _PostComposerSheet();

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
  PostVisibility _visibility = PostVisibility.public;

  bool _asClub = true;
  bool _busy = false;

  static const _maxMedia = 8;

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
      setState(() => _media
          .add(PickedMedia(bytes: picked.bytes, name: picked.name)));
    } catch (e) {
      _snack('Görsel seçilemedi: $e', SwanPalette.light.danger);
    }
  }

  Future<void> _share(String? clubId) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _media.isEmpty) {
      _snack('Bir şeyler yaz ya da görsel ekle', SwanPalette.light.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(socialServiceProvider).createPost(
            body: text,
            clubId: clubId,
            images: _media,
            // Kulüp adına paylaşımda görünürlük seçimi anlamsız: kulüp
            // gönderisi zaten kulüp kitlesine yazılıyor.
            visibility:
                clubId != null ? null : visibilityKey(_visibility),
          );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];
    final demo = ref.watch(demoRoleProvider);

    // Kulüp adına paylaşım YALNIZCA kulüp yetkililerine açıktır (yönetici veya
    // antrenör). Sporcu/veli/üye kulüp adına paylaşamaz — bu kural veritabanında
    // da `can_post_for_club()` ile ayrıca zorlanır.
    // Demo rolü aktifse gerçek üyelik yerine o rol esas alınır, aksi hâlde demo
    // "Sporcu" iken bile gerçek yöneticilik yetkisi sızardı.
    final canPostPersonally = demo != null
        ? demo.canPostPersonally
        : creds.any((c) => c.status == 'approved');
    final canPostAsClub = club != null &&
        (demo != null
            ? demo.canPostAsClub
            : (club.role == 'club_admin' || club.role == 'coach'));
    final effectiveAsClub = canPostAsClub && (_asClub || !canPostPersonally);
    final canShare = canPostAsClub || canPostPersonally;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: grip, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Yeni Gönderi', style: SwanType.h2(ink)),
          const SizedBox(height: 14),

          if (!canShare) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SwanPalette.light.warning.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: SwanPalette.light.warning.withValues(alpha: .4)),
              ),
              child: Row(children: [
                Icon(Icons.verified_user_rounded,
                    size: 20, color: SwanPalette.light.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Paylaşım yapmak için kimliğini doğrulatmalısın '
                      '(antrenör kademesi veya sporcu lisansı).',
                      style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () {
                Navigator.pop(context, false);
                Navigator.pushNamed(context, '/dogrulama');
              },
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text('Doğrulamaya Git',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
              ),
            ),
          ] else ...[
            // Kimin adına paylaşılıyor
            if (canPostAsClub && canPostPersonally) ...[
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: alt, borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  _who('Kulüp adına', true, ink, surf),
                  _who('Kendi adıma', false, ink, surf),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            Row(children: [
              Icon(
                  effectiveAsClub
                      ? Icons.account_balance_rounded
                      : Icons.person_rounded,
                  size: 16,
                  color: kTeal),
              const SizedBox(width: 7),
              Text(
                  effectiveAsClub
                      ? '${club.name} adına paylaşılacak'
                      : 'Kendi adına paylaşılacak',
                  style: SwanType.caption(kTeal, w: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),

            TextField(
              controller: _ctrl,
              minLines: 3,
              maxLines: 8,
              autofocus: true,
              style: SwanType.bodySm(ink).copyWith(height: 1.45),
              decoration: InputDecoration(
                hintText: 'Neler oluyor?',
                hintStyle:
                    SwanType.bodySm(SwanColors.textSecondary),
                filled: true,
                fillColor: alt,
                contentPadding: const EdgeInsets.all(16),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: kTeal, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),

            if (_media.isNotEmpty) ...[
              // İlk görsel büyük — akıştaki görünümle aynı oran. Gerisi
              // altında şerit; sıra, gönderideki sırayla aynı.
              Stack(children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: RatioImage(
                    image: MemoryImage(_media.first.bytes),
                    borderRadius: 16,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _media.removeAt(0)),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 17),
                    ),
                  ),
                ),
                if (_media.length > 1)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .55),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('${_media.length}/$_maxMedia',
                          style: SwanType.caption(Colors.white,
                              w: FontWeight.w700)),
                    ),
                  ),
              ]),
              if (_media.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 62,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _media.length - 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final idx = i + 1;
                      return Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(_media[idx].bytes,
                              width: 62, height: 62, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _media.removeAt(idx)),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .6),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(Icons.close_rounded,
                                  color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],

            // Görünürlük — yalnızca kişisel paylaşımda. Kulüp gönderisi
            // zaten kulüp kitlesine yazılıyor.
            if (!effectiveAsClub) ...[
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final v in const [
                      PostVisibility.public,
                      PostVisibility.followers,
                      PostVisibility.club,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _visibility = v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 7),
                            decoration: BoxDecoration(
                              color: _visibility == v ? kTeal : alt,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color:
                                      _visibility == v ? kTeal : line),
                            ),
                            child: Text(
                              visibilityLabel(v),
                              style: SwanType.caption(
                                  _visibility == v ? Colors.white : ink,
                                  w: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: alt,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: line),
                  ),
                  child: Row(children: [
                    const Icon(Icons.image_rounded, size: 18, color: kTeal),
                    const SizedBox(width: 8),
                    Text(_media.isEmpty ? 'Görsel Ekle' : 'Bir tane daha',
                        style: SwanType.caption(ink, w: FontWeight.w700)),
                  ]),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _busy
                    ? null
                    : () => _share(effectiveAsClub ? club.id : null),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 13),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kTealBright, kTeal]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withValues(alpha: .32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(_busy ? 'Paylaşılıyor…' : 'Paylaş',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _who(String label, bool clubMode, Color ink, Color surf) {
    final on = _asClub == clubMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _asClub = clubMode),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? surf : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: SwanType.caption(on ? ink : SwanColors.textSecondary, w: FontWeight.w800)),
        ),
      ),
    );
  }
}
