import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_brand.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';

/// Kulüp profilini düzenleme.
///
/// **Bu ekran daha önce yoktu.** `clubs` tablosunda `logo_path`, `bio`,
/// `phone`, `website`, `instagram`, `founded_year` sütunları duruyordu ve
/// mobilden hiçbiri doldurulamıyordu; `/kulup-profil` yalnızca görüntüleme
/// açıyordu.
///
/// Görseller `set_club_media` RPC'siyle yazılıyor: yükleme istemcide ama
/// yolun **bu kulübün** klasörüne ait olduğunu sunucu doğruluyor. Yoksa bir
/// kulüp yöneticisi başka kulübün görselini kendi kapağı yapabilirdi.
Future<bool?> showClubEditSheet(BuildContext context, String clubId) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClubEditSheet(clubId: clubId),
    );

class _ClubEditSheet extends ConsumerStatefulWidget {
  const _ClubEditSheet({required this.clubId});

  final String clubId;

  @override
  ConsumerState<_ClubEditSheet> createState() => _ClubEditSheetState();
}

class _ClubEditSheetState extends ConsumerState<_ClubEditSheet> {
  ClubIdentity? _club;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _bio = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _instagram = TextEditingController();
  final _address = TextEditingController();
  final _founded = TextEditingController();

  String? _brand;
  late List<String> _sections = List.of(ClubSection.defaults);

  Uint8List? _logoBytes;
  String? _logoName;
  Uint8List? _coverBytes;
  String? _coverName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _shortName, _bio, _phone, _email,
      _website, _instagram, _address, _founded,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await ref
          .read(clubConfigServiceProvider)
          .identity(widget.clubId);
      if (!mounted) return;
      setState(() {
        _club = c;
        _loading = false;
        if (c != null) {
          _name.text = c.name;
          _shortName.text = c.shortName ?? '';
          _bio.text = c.bio ?? '';
          _phone.text = c.phone ?? '';
          _email.text = c.email ?? '';
          _website.text = c.website ?? '';
          _instagram.text = c.instagram ?? '';
          _address.text = c.address ?? '';
          _founded.text = c.foundedYear?.toString() ?? '';
          _brand = c.brandColor;
          _sections = List.of(c.effectiveSections);
        }
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _pick(bool cover) async {
    try {
      final picked = await pickImage();
      if (picked == null || !mounted) return;
      setState(() {
        if (cover) {
          _coverBytes = picked.bytes;
          _coverName = picked.name;
        } else {
          _logoBytes = picked.bytes;
          _logoName = picked.name;
        }
      });
    } catch (e) {
      _snack('Görsel seçilemedi: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final svc = ref.read(clubConfigServiceProvider);
    try {
      await svc.updateIdentity(
        widget.clubId,
        name: _name.text,
        shortName: _shortName.text,
        bio: _bio.text,
        phone: _phone.text,
        email: _email.text,
        website: _website.text,
        instagram: _instagram.text,
        address: _address.text,
        foundedYear: int.tryParse(_founded.text.trim()) ?? 0,
        brandColor: _brand ?? '',
        sections: _sections,
      );

      // Görseller ayrı: yükleme istemcide, yol doğrulaması sunucuda.
      String? logoPath;
      String? coverPath;
      if (_logoBytes != null) {
        logoPath = await svc.uploadMedia(widget.clubId,
            bytes: _logoBytes!, fileName: _logoName!, kind: 'logo');
      }
      if (_coverBytes != null) {
        coverPath = await svc.uploadMedia(widget.clubId,
            bytes: _coverBytes!, fileName: _coverName!, kind: 'cover');
      }
      if (logoPath != null || coverPath != null) {
        await svc.setMedia(widget.clubId,
            logoPath: logoPath, coverPath: coverPath);
      }

      ref.invalidate(clubSocialProfileProvider(widget.clubId));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

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
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.all(SwanSpace.xl),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(SwanSpace.lg),
                      child: premiumError(context, _error!),
                    )
                  : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    final c = context.swan;
    final tone = BrandTone.from(_brand, c);

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(SwanSpace.lg),
      children: [
        Row(children: [
          Text('Kulüp profili', style: SwanType.h3(c.ink)),
          const Spacer(),
          if (_busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            GestureDetector(
              onTap: _save,
              child: Container(
                height: 34,
                padding:
                    const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Kaydet düğmesi TEAL — marka rengi değil. Teal bu
                  // uygulamada "birincil aksiyon" anlamına geliyor; kulübün
                  // rengi kırmızıysa bu düğme `danger` ile karışırdı.
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text('Kaydet',
                    style:
                        SwanType.caption(Colors.white, w: FontWeight.w800)),
              ),
            ),
        ]),
        const SizedBox(height: SwanSpace.lg),

        // ------------------------------------------------------ görünüm
        _sectionTitle(c, 'Görünüm'),
        _coverPicker(context, tone),
        const SizedBox(height: SwanSpace.md),
        Row(children: [
          _logoPicker(context),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Text(
              'Logo kartlarda ve listelerde, kapak yalnızca kulüp '
              'sayfasında görünüyor.',
              style: SwanType.caption(c.inkMuted),
            ),
          ),
        ]),
        const SizedBox(height: SwanSpace.md),
        _brandPicker(context),

        const SizedBox(height: SwanSpace.xl),
        _sectionTitle(c, 'Bilgiler'),
        _field(c, 'Kulüp adı', _name),
        _field(c, 'Kısa ad', _shortName, hint: 'SSK'),
        _field(c, 'Hakkında', _bio, maxLines: 3),
        _field(c, 'Kuruluş yılı', _founded,
            hint: '1998', keyboard: TextInputType.number),

        const SizedBox(height: SwanSpace.xl),
        _sectionTitle(c, 'İletişim'),
        _field(c, 'Telefon', _phone, keyboard: TextInputType.phone),
        _field(c, 'E-posta', _email, keyboard: TextInputType.emailAddress),
        _field(c, 'Web sitesi', _website, hint: 'kulup.org'),
        _field(c, 'Instagram', _instagram, hint: 'kulupadi', prefix: '@'),
        _field(c, 'Adres', _address, maxLines: 2),

        const SizedBox(height: SwanSpace.xl),
        _sectionTitle(c, 'Profil bölümleri'),
        Text(
          'Kulüp sayfanda hangi bölümler görünsün. Dokunarak kapat, oklarla '
          'sırala.',
          style: SwanType.caption(c.inkMuted),
        ),
        const SizedBox(height: SwanSpace.sm),
        _sectionEditor(context),
        const SizedBox(height: SwanSpace.xl),
      ],
    );
  }

  Widget _sectionTitle(SwanPalette c, String t) => Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.sm),
        child: Text(t, style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
      );

  Widget _coverPicker(BuildContext context, BrandTone tone) {
    final c = context.swan;
    final existing = _club?.coverPath;

    return GestureDetector(
      onTap: () => _pick(true),
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: tone.base,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
          image: _coverBytes != null
              ? DecorationImage(
                  image: MemoryImage(_coverBytes!), fit: BoxFit.cover)
              : (existing != null
                  ? DecorationImage(
                      image: NetworkImage(_publicUrl(existing)),
                      fit: BoxFit.cover)
                  : null),
        ),
        alignment: Alignment.center,
        child: _pill(
            context,
            Icons.image_rounded,
            _coverBytes == null && existing == null
                ? 'Kapak ekle'
                : 'Kapağı değiştir'),
      ),
    );
  }

  Widget _logoPicker(BuildContext context) {
    final c = context.swan;
    final existing = _club?.logoPath;

    return GestureDetector(
      onTap: () => _pick(false),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
          border: Border.all(color: c.line),
          image: _logoBytes != null
              ? DecorationImage(
                  image: MemoryImage(_logoBytes!), fit: BoxFit.cover)
              : (existing != null
                  ? DecorationImage(
                      image: NetworkImage(_publicUrl(existing)),
                      fit: BoxFit.cover)
                  : null),
        ),
        child: _logoBytes == null && existing == null
            ? Icon(Icons.add_photo_alternate_rounded,
                size: 22, color: c.inkMuted)
            : null,
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: SwanType.caption(Colors.white, w: FontWeight.w700)),
        ]),
      );

  Widget _brandPicker(BuildContext context) {
    final c = context.swan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Kulüp rengi',
          style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        'Kapak bandında ve rozetlerde görünür. Düğmeler ve sekmeler '
        'uygulamanın kendi rengiyle kalır.',
        style: SwanType.caption(c.inkMuted),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
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

  /// Bölüm sırası ve görünürlüğü.
  ///
  /// Kapatılan bölüm listeden çıkarılıyor, altta "kapalı" olarak duruyor ve
  /// tekrar açılabiliyor. Boş liste geçerli: "hiçbir bölüm gösterme".
  Widget _sectionEditor(BuildContext context) {
    final c = context.swan;
    final hidden =
        ClubSection.defaults.where((k) => !_sections.contains(k)).toList();

    return Column(children: [
      for (var i = 0; i < _sections.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md, vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            border: Border.all(color: c.line),
          ),
          child: Row(children: [
            Expanded(
              child: Text(ClubSection.label(_sections[i]),
                  style: SwanType.bodySm(c.ink)),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_upward_rounded),
              onPressed: i == 0
                  ? null
                  : () => setState(() {
                        final x = _sections.removeAt(i);
                        _sections.insert(i - 1, x);
                      }),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.arrow_downward_rounded),
              onPressed: i == _sections.length - 1
                  ? null
                  : () => setState(() {
                        final x = _sections.removeAt(i);
                        _sections.insert(i + 1, x);
                      }),
            ),
            IconButton(
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.visibility_off_rounded),
              onPressed: () => setState(() => _sections.removeAt(i)),
            ),
          ]),
        ),
      if (hidden.isNotEmpty) ...[
        const SizedBox(height: SwanSpace.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Kapalı bölümler',
              style: SwanType.caption(c.inkMuted, w: FontWeight.w700)),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in hidden)
              GestureDetector(
                onTap: () => setState(() => _sections.add(k)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 13, color: c.inkMuted),
                    const SizedBox(width: 4),
                    Text(ClubSection.label(k),
                        style: SwanType.caption(c.inkMuted)),
                  ]),
                ),
              ),
          ],
        ),
      ],
    ]);
  }

  Widget _field(SwanPalette c, String label, TextEditingController ctrl,
      {String? hint,
      int maxLines = 1,
      String? prefix,
      TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.md),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: SwanType.bodySm(c.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          isDense: true,
          labelStyle: SwanType.caption(c.inkMuted),
          hintStyle: SwanType.bodySm(c.inkMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            borderSide: BorderSide(color: c.line),
          ),
        ),
      ),
    );
  }

  /// `post-media` public bucket; yol doğrudan URL'e çevriliyor.
  String _publicUrl(String path) =>
      ref.read(supabaseClientProvider).storage.from('post-media').getPublicUrl(path);
}
