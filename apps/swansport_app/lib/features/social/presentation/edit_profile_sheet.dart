import 'dart:typed_data';
import 'package:swansport_core/swansport_core.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_brand.dart';
import '../../../app/design/swan_shape.dart';

/// Profil düzenleme sayfasını açar. Kaydedilirse true döner.
Future<bool?> showEditProfileSheet(BuildContext context, SocialProfile p) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _EditProfileSheet(profile: p),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final SocialProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _username =
      TextEditingController(text: widget.profile.username ?? '');
  late final _bio = TextEditingController(text: widget.profile.bio ?? '');
  Uint8List? _avatarBytes;
  String? _avatarName;
  Uint8List? _coverBytes;
  String? _coverName;
  bool _busy = false;
  late String? _cityCode = widget.profile.cityCode;

  /// `#RRGGBB` ya da null. Null = renk yok, uygulamanın kendi kimliği.
  late String? _brand = widget.profile.brandColor;

  /// null = addan türet (bugünkü davranış). Kullanıcı seçerse 0-7.
  late int? _tint = widget.profile.avatarTint;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    try {
      final picked = await pickImage();
      if (picked == null || !mounted) return;
      setState(() {
        _coverBytes = picked.bytes;
        _coverName = picked.name;
      });
    } catch (e) {
      _snack('Kapak seçilemedi: $e', SwanPalette.light.danger);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await pickImage();
      if (picked == null || !mounted) return;
      setState(() {
        _avatarBytes = picked.bytes;
        _avatarName = picked.name;
      });
    } catch (e) {
      _snack('Görsel seçilemedi: $e', SwanPalette.light.danger);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(socialServiceProvider).updateProfile(
            fullName: _name.text,
            username: _username.text,
            bio: _bio.text,
            avatarBytes: _avatarBytes,
            avatarName: _avatarName,
            coverBytes: _coverBytes,
            coverName: _coverName,
            // Değişmediyse gönderilmiyor; boş metin "temizle" demek.
            brandColor: _brand == widget.profile.brandColor
                ? null
                : (_brand ?? ''),
            // -1 = temizle. null'ın "dokunma" ile "sıfırla" anlamlarını
            // ayırmanın başka yolu yok.
            avatarTint: _tint == widget.profile.avatarTint
                ? null
                : (_tint ?? -1),
            // Yalnızca değiştiyse gönder — dokunulmamış alan yazılmasın.
            cityCode: _cityCode == widget.profile.cityCode
                ? null
                : (_cityCode ?? ''),
          );
      ref.invalidate(currentProfileProvider);
      // Şehir değişmiş olabilir: uygun topluluklara katılımı tazele.
      await ref.read(communityServiceProvider).ensureMine();
      ref.invalidate(communityListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = '$e'.contains('duplicate') || '$e'.contains('unique')
          ? 'Bu kullanıcı adı alınmış, başka bir tane dene.'
          : 'Kaydedilemedi: $e';
      _snack(msg, SwanPalette.light.danger);
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
    final grip = isDark ? const Color(0xFF2E3B4E) : const Color(0xFFE4E9F0);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
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
            Text('Profili Düzenle', style: SwanType.h2(ink)),
            const SizedBox(height: 18),

            // Avatar
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(children: [
                  _avatarBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: Image.memory(_avatarBytes!,
                              width: 84, height: 84, fit: BoxFit.cover),
                        )
                      : SocialAvatar(
                          initials: widget.profile.initials,
                          imageUrl: widget.profile.avatarUrl,
                          size: 84,
                          radius: 26,
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: surf, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            _field(isDark, 'Ad Soyad', _name, 'Adın'),
            const SizedBox(height: 14),
            _field(isDark, 'Kullanıcı adı', _username, 'kullaniciadi',
                prefix: '@'),
            const SizedBox(height: 14),
            _field(isDark, 'Biyografi', _bio, 'Kendini kısaca anlat…',
                maxLines: 3),
            const SizedBox(height: 14),
            _cityField(isDark),
            const SizedBox(height: 20),

            // ---------------------------------------------------- kimlik
            Text('Görünüm', style: SwanType.h3(context.swan.ink)),
            const SizedBox(height: 4),
            Text(
              'Kapak ve renk yalnızca profilinde görünür. Düğmeler ve '
              'sekmeler uygulamanın kendi rengiyle kalır.',
              style: SwanType.caption(context.swan.inkMuted),
            ),
            const SizedBox(height: 12),
            _coverPicker(context),
            const SizedBox(height: 14),
            _brandPicker(context),
            const SizedBox(height: 14),
            _tintPicker(context),
            const SizedBox(height: 20),

            GestureDetector(
              onTap: _busy ? null : _save,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: .32),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet',
                    style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç',
                    style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// İl seçici — 81 il veritabanından gelir, tek kaynak.
  /// Şehir topluluk üyeliğini belirlediği için serbest metin değil, seçim.
  Widget _cityField(bool isDark) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityRow>[];
    final selected = cities.where((c) => c.code == _cityCode).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Şehir', style: SwanType.h3(ink)),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: cities.isEmpty ? null : () => _pickCity(cities),
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: alt,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: line),
            ),
            child: Row(children: [
              Expanded(
                child: Text(
                  selected?.name ?? 'Şehir seç',
                  style: SwanType.bodySm(selected == null ? SwanColors.textSecondary : ink),
                ),
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 20, color: SwanColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text('İlinin antrenör topluluğuna katılmak için gerekli.',
            style: SwanType.caption(SwanColors.textSecondary)),
      ],
    );
  }


  Future<void> _pickCity(List<CityRow> cities) async {
    final picked = await _pickFrom(cities, _cityCode, 'Şehir seç');
    if (picked != null && mounted) setState(() => _cityCode = picked);
  }

  /// Ortak liste seçici — şehir ve branş aynı bileşeni kullanır.
  Future<String?> _pickFrom(
      List<CityRow> items, String? current, String title) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final search = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final q = search.text.trim().toLowerCase();
        final list = q.isEmpty
            ? items
            : items.where((c) => trContains(c.name, q)).toList();
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(children: [
            Text(title, style: SwanType.h3(ink)),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              autofocus: true,
              onChanged: (_) => setSheet(() {}),
              style: SwanType.bodySm(ink),
              decoration: InputDecoration(
                hintText: 'Ara…',
                hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(list[i].name,
                      style: SwanType.bodySm(ink, w: FontWeight.w600)),
                  trailing: list[i].code == current
                      ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                      : null,
                  onTap: () => Navigator.pop(ctx, list[i].code),
                ),
              ),
            ),
          ]),
        );
      }),
    );

    return picked;
  }

  /// Kapak seçimi — önizleme canlı, marka rengiyle birlikte.
  Widget _coverPicker(BuildContext context) {
    final c = context.swan;
    final tone = BrandTone.from(_brand, c);

    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          color: tone.base,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
          image: _coverBytes != null
              ? DecorationImage(
                  image: MemoryImage(_coverBytes!), fit: BoxFit.cover)
              : (widget.profile.coverUrl != null
                  ? DecorationImage(
                      image: NetworkImage(widget.profile.coverUrl!),
                      fit: BoxFit.cover)
                  : null),
        ),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.image_rounded, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              _coverBytes == null && widget.profile.coverUrl == null
                  ? 'Kapak ekle'
                  : 'Kapağı değiştir',
              style: SwanType.caption(Colors.white, w: FontWeight.w700),
            ),
          ]),
        ),
      ),
    );
  }

  /// Marka rengi. Seçilen renk kimlik yüzeylerinde kullanılıyor; üstündeki
  /// yazı rengi ölçülerek belirleniyor, o yüzden her renk güvenli.
  Widget _brandPicker(BuildContext context) {
    final c = context.swan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Renk', style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        // "Renk yok" seçeneği: uygulamanın kendi kimliğine dönüş.
        _swatch(context, null, _brand == null,
            () => setState(() => _brand = null)),
        for (final hex in kBrandSwatches)
          _swatch(context, hex, _brand?.toUpperCase() == hex,
              () => setState(() => _brand = hex)),
      ]),
    ]);
  }

  Widget _swatch(
      BuildContext context, String? hex, bool selected, VoidCallback onTap) {
    final c = context.swan;
    final tone = BrandTone.from(hex, c);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: hex == null ? c.surfaceAlt : tone.base,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
          border: Border.all(
              color: selected ? c.ink : c.line, width: selected ? 2 : 1),
        ),
        child: hex == null
            ? Icon(Icons.block_rounded, size: 15, color: c.inkMuted)
            : (selected
                ? Icon(Icons.check_rounded, size: 16, color: tone.ink)
                : null),
      ),
    );
  }

  /// Avatar arka planı. Bugüne kadar addan türetiliyordu; seçim yapılmazsa
  /// aynen öyle kalıyor.
  Widget _tintPicker(BuildContext context) {
    final c = context.swan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Avatar arka planı',
          style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < 4; i++)
          GestureDetector(
            onTap: () => setState(() => _tint = i),
            child: Opacity(
              opacity: _tint == i ? 1 : 0.55,
              child: SocialAvatar(
                initials: widget.profile.initials,
                size: 40,
                radius: SwanRadius.sm,
                gradientIndex: i,
              ),
            ),
          ),
        GestureDetector(
          onTap: () => setState(() => _tint = null),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              border: Border.all(
                  color: _tint == null ? c.ink : c.line,
                  width: _tint == null ? 2 : 1),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 16, color: c.inkMuted),
          ),
        ),
      ]),
    ]);
  }

  Widget _field(bool isDark, String label, TextEditingController ctrl,
      String hint,
      {int maxLines = 1, String? prefix}) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
        const SizedBox(height: 7),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: SwanType.bodySm(ink, w: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixStyle: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700),
            hintStyle:
                SwanType.bodySm(SwanColors.textSecondary),
            filled: true,
            fillColor: alt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: kTeal, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
