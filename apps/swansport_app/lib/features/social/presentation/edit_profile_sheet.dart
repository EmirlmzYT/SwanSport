import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_picker_sheet.dart';
import '../../../app/widgets/friendly_error.dart';
import '../../../app/widgets/swan_city_picker.dart';
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
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _instagram =
      TextEditingController(text: widget.profile.instagram ?? '');
  late final _twitter =
      TextEditingController(text: widget.profile.twitter ?? '');
  late final _website =
      TextEditingController(text: widget.profile.website ?? '');
  late bool _phoneHidden = widget.profile.phoneHidden;
  late final _primarySport =
      TextEditingController(text: widget.profile.primarySport ?? '');
  late final _position =
      TextEditingController(text: widget.profile.position ?? '');
  late final _height = TextEditingController(
    text: widget.profile.heightCm != null ? '${widget.profile.heightCm}' : '',
  );
  late final _weight = TextEditingController(
    text: widget.profile.weightKg != null ? '${widget.profile.weightKg}' : '',
  );
  late String? _dominantSide = widget.profile.dominantSide;
  Uint8List? _avatarBytes;
  String? _avatarName;
  Uint8List? _coverBytes;
  String? _coverName;
  bool _busy = false;
  late String? _cityCode = widget.profile.cityCode;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    _phone.dispose();
    _instagram.dispose();
    _twitter.dispose();
    _website.dispose();
    _primarySport.dispose();
    _position.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked =
          await showSingleImagePicker(context, title: 'Profil fotoğrafı');
      if (picked == null || !mounted) return;
      setState(() {
        _avatarBytes = picked.bytes;
        _avatarName = picked.name;
      });
    } catch (e) {
      _snack('Görsel seçilemedi: $e', context.swan.danger);
    }
  }

  Future<void> _pickCover() async {
    try {
      final picked =
          await showSingleImagePicker(context, title: 'Kapak fotoğrafı');
      if (picked == null || !mounted) return;
      setState(() {
        _coverBytes = picked.bytes;
        _coverName = picked.name;
      });
      _snack('Kapak fotoğrafı seçildi', context.swan.accent);
    } catch (e) {
      _snack('Kapak seçilemedi: $e', context.swan.danger);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(socialServiceProvider).updateProfile(
            fullName: _name.text,
            username: _username.text,
            bio: _bio.text,
            phone: _phone.text.trim().isEmpty ? '' : _phone.text.trim(),
            phoneHidden: _phoneHidden,
            instagram: _instagram.text.trim(),
            twitter: _twitter.text.trim(),
            website: _website.text.trim(),
            primarySport: _primarySport.text.trim(),
            position: _position.text.trim(),
            heightCm: int.tryParse(_height.text.trim()),
            weightKg: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
            dominantSide: _dominantSide,
            avatarBytes: _avatarBytes,
            avatarName: _avatarName,
            coverBytes: _coverBytes,
            coverName: _coverName,
            cityCode:
                _cityCode == widget.profile.cityCode ? null : (_cityCode ?? ''),
          );
      ref.invalidateSwanAccess();
      await ref.read(communityServiceProvider).ensureMine();
      ref.invalidate(communityListProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = '$e'.contains('duplicate') || '$e'.contains('unique')
          ? 'Bu kullanıcı adı alınmış, başka bir tane dene.'
          : friendlyErrorMessage(e, defaultMessage: 'Profil güncellenemedi. Lütfen tekrar deneyin.');
      if (mounted) _snack(msg, context.swan.danger);
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .90,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 1. Üst Bar: [Vazgeç]  Profili Düzenle  [Bitti]
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _busy ? null : () => Navigator.pop(context, false),
                  child: Text(
                    'Vazgeç',
                    style: SwanType.body(c.inkMuted, w: FontWeight.w500),
                  ),
                ),
                Text(
                  'Profili Düzenle',
                  style: SwanType.body(c.ink, w: FontWeight.w700),
                ),
                GestureDetector(
                  onTap: _busy ? null : _save,
                  child: _busy
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.accent,
                          ),
                        )
                      : Text(
                          'Bitti',
                          style: SwanType.body(c.accent, w: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: c.line.withValues(alpha: .6),
          ),

          // 2. İçerik Alanı
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
              child: Column(
                children: [
                  // Profil Fotoğrafı (Merkezde)
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.line.withValues(alpha: .5),
                            width: 1,
                          ),
                        ),
                        child: ClipOval(
                          child: _avatarBytes != null
                              ? Image.memory(
                                  _avatarBytes!,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                )
                              : SocialAvatar(
                                  initials: widget.profile.initials,
                                  imageUrl: widget.profile.avatarUrl,
                                  size: 86,
                                  radius: 43,
                                  gradientIndex: widget.profile.avatarTint ??
                                      (widget.profile.name.length % 4),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: Text(
                          'Fotoğrafı Değiştir',
                          style: SwanType.bodySm(c.accent, w: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: SwanType.caption(c.inkMuted),
                      ),
                      GestureDetector(
                        onTap: _pickCover,
                        child: Text(
                          _coverBytes != null
                              ? 'Kapak Seçildi ✓'
                              : 'Kapağı Değiştir',
                          style: SwanType.bodySm(
                            _coverBytes != null ? c.accent : c.inkMuted,
                            w: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Sade Instagram Satırları
                  _simpleRow(
                    label: 'Ad',
                    child: TextField(
                      controller: _name,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'Adın',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Kullanıcı adı',
                    child: TextField(
                      controller: _username,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: SwanType.body(c.inkMuted),
                        hintText: 'kullaniciadi',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Biyografi',
                    alignTop: true,
                    child: TextField(
                      controller: _bio,
                      maxLength: 150,
                      maxLines: 3,
                      minLines: 1,
                      buildCounter: (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) =>
                          Text(
                        '$currentLength / $maxLength',
                        style: SwanType.caption(c.inkMuted),
                      ),
                      style: SwanType.body(c.ink).copyWith(height: 1.35),
                      decoration: InputDecoration(
                        hintText: 'Kendini kısaca anlat…',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        counterText: null,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _cityRow(context),
                  _divider(c),

                  _simpleRow(
                    label: 'Spor Branşı',
                    child: TextField(
                      controller: _primarySport,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'Örn: Futbol, Basketbol, Tenis…',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Mevki / Rol',
                    child: TextField(
                      controller: _position,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'Örn: Forvet, Oyun Kurucu…',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Boy (cm)',
                    child: TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'Örn: 182',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Kilo (kg)',
                    child: TextField(
                      controller: _weight,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'Örn: 75',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _dominantSideRow(context),
                  _divider(c),

                  _simpleRow(
                    label: 'Instagram',
                    child: TextField(
                      controller: _instagram,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: SwanType.body(c.inkMuted),
                        hintText: 'kullaniciadi',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Twitter / X',
                    child: TextField(
                      controller: _twitter,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        prefixText: '@',
                        prefixStyle: SwanType.body(c.inkMuted),
                        hintText: 'kullaniciadi',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Web sitesi',
                    child: TextField(
                      controller: _website,
                      keyboardType: TextInputType.url,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: 'https://ornek.com',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  _simpleRow(
                    label: 'Telefon',
                    child: TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: SwanType.body(c.ink),
                      decoration: InputDecoration(
                        hintText: '05xx xxx xx xx',
                        hintStyle:
                            SwanType.body(c.inkMuted.withValues(alpha: .5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  _divider(c),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Telefon numarasını gizle',
                                style:
                                    SwanType.bodySm(c.ink, w: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _phoneHidden
                                    ? 'Numaranız profilinizde diğer kullanıcılara görünmez.'
                                    : 'Numaranız profilinizi ziyaret eden herkese görünür.',
                                style: SwanType.caption(c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _phoneHidden,
                          activeTrackColor: c.accent,
                          onChanged: (val) =>
                              setState(() => _phoneHidden = val),
                        ),
                      ],
                    ),
                  ),
                  _divider(c),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(SwanPalette c) =>
      Divider(height: 1, thickness: 0.5, color: c.line.withValues(alpha: .5));

  Widget _simpleRow({
    required String label,
    required Widget child,
    bool alignTop = false,
  }) {
    final c = context.swan;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 105,
            child: Padding(
              padding: EdgeInsets.only(top: alignTop ? 8 : 0),
              child: Text(
                label,
                style: SwanType.bodySm(c.inkMuted, w: FontWeight.w600),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _cityRow(BuildContext context) {
    final c = context.swan;
    final cities = ref.watch(citiesProvider).valueOrNull ?? kTurkeyCities;
    final selected = cities.where((ci) => ci.code == _cityCode).firstOrNull;

    return InkWell(
      onTap: () async {
        final picked = await showSwanCityPicker(
          context,
          selectedCode: _cityCode,
          selectedCity: selected?.name,
        );
        if (picked != null && mounted) {
          setState(() => _cityCode = picked.code);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 105,
              child: Text(
                'Şehir',
                style: SwanType.bodySm(c.inkMuted, w: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Text(
                selected?.name ?? 'Şehir seçiniz',
                style: SwanType.body(
                  selected == null ? c.inkMuted.withValues(alpha: .5) : c.ink,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: c.inkMuted),
          ],
        ),
      ),
    );
  }

  Widget _dominantSideRow(BuildContext context) {
    final c = context.swan;
    const options = ['Sağ', 'Sol', 'Her ikisi'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 105,
            child: Text(
              'Baskın Taraf',
              style: SwanType.bodySm(c.inkMuted, w: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              children: options.map((opt) {
                final selected = _dominantSide == opt;
                return ChoiceChip(
                  label: Text(
                    opt,
                    style: SwanType.caption(
                      selected ? c.onAccent : c.ink,
                      w: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  selectedColor: c.accent,
                  backgroundColor: c.surfaceAlt,
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: selected ? c.accent : c.line.withValues(alpha: .4),
                    ),
                  ),
                  onSelected: (val) {
                    setState(() {
                      _dominantSide = val ? opt : null;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

}
