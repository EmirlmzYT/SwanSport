import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';

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
  bool _busy = false;
  late String? _cityCode = widget.profile.cityCode;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
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
      _snack('Görsel seçilemedi: $e', const Color(0xFFF43F5E));
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
      _snack(msg, const Color(0xFFF43F5E));
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
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
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
            Text('Profili Düzenle', style: sora(20, FontWeight.w800, ink)),
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
                    style: jakarta(14.5, FontWeight.w800, Colors.white)),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Vazgeç',
                    style: jakarta(
                        13, FontWeight.w700, SwanColors.textSecondary)),
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
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final cities = ref.watch(citiesProvider).valueOrNull ?? const <CityRow>[];
    final selected = cities.where((c) => c.code == _cityCode).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ŞEHİR',
            style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
                ls: 1.1)),
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
                  style: jakarta(13.5, FontWeight.w500,
                      selected == null ? SwanColors.textSecondary : ink),
                ),
              ),
              const Icon(Icons.expand_more_rounded,
                  size: 20, color: SwanColors.textSecondary),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text('İlinin antrenör topluluğuna katılmak için gerekli.',
            style: jakarta(10.5, FontWeight.w500, SwanColors.textSecondary)),
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
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final search = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final q = search.text.trim().toLowerCase();
        final list = q.isEmpty
            ? items
            : items.where((c) => c.name.toLowerCase().contains(q)).toList();
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
            Text(title, style: sora(18, FontWeight.w800, ink)),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              autofocus: true,
              onChanged: (_) => setSheet(() {}),
              style: jakarta(13.5, FontWeight.w500, ink),
              decoration: InputDecoration(
                hintText: 'Ara…',
                hintStyle: jakarta(
                    13, FontWeight.w500, SwanColors.textSecondary),
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
                      style: jakarta(13.5, FontWeight.w600, ink)),
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

  Widget _field(bool isDark, String label, TextEditingController ctrl,
      String hint,
      {int maxLines = 1, String? prefix}) {
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: jakarta(10.5, FontWeight.w800, SwanColors.textSecondary,
                ls: 1.1)),
        const SizedBox(height: 7),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: jakarta(13.5, FontWeight.w600, ink),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            prefixStyle: jakarta(13.5, FontWeight.w700, SwanColors.textSecondary),
            hintStyle:
                jakarta(13, FontWeight.w500, SwanColors.textSecondary),
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
