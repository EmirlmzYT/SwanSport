import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';

/// Malzeme ilanı formu.
///
/// Neden ayrı bir form: ortak `showQuickForm` yalnızca düz metin alanı
/// destekliyor. Fiyat (sayısal), durum (seçim) ve fotoğraf ona sığmıyordu;
/// zorlamak yerine malzemeye kendi sayfasını verdik. Diğer dört ilan türü
/// bugünkü akışında kaldı.
class EquipmentListingSheet extends ConsumerStatefulWidget {
  const EquipmentListingSheet({
    required this.kind,
    required this.clubId,
    super.key,
  });

  /// `equipmentSale` ya da `equipmentWanted`.
  final ListingKind kind;

  /// Kulüp adına veriliyorsa kulübün kimliği; kişisel ilanda null.
  final String? clubId;

  @override
  ConsumerState<EquipmentListingSheet> createState() =>
      _EquipmentListingSheetState();
}

class _EquipmentListingSheetState extends ConsumerState<EquipmentListingSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _price = TextEditingController();

  ListingCondition? _condition;
  PickedImage? _image;
  bool _busy = false;
  String? _error;

  bool get _isSale => widget.kind == ListingKind.equipmentSale;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _price.dispose();
    super.dispose();
  }

  /// Kullanıcı "1.250,50" da yazabilir "1250.5" da. İkisini de kabul edip
  /// reddetmek yerine ondalık ayıracını normalleştiriyoruz.
  num? get _parsedPrice {
    final raw = _price.text.trim();
    if (raw.isEmpty) return null;
    return num.tryParse(raw.replaceAll('.', '').replaceAll(',', '.'));
  }

  Future<void> _pick() async {
    final picked = await pickImage();
    if (picked != null && mounted) setState(() => _image = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Başlık gerekiyor');
      return;
    }
    if (_isSale && _price.text.trim().isNotEmpty && _parsedPrice == null) {
      setState(() => _error = 'Fiyatı anlayamadım — örnek: 1250 ya da 1.250,50');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final service = ref.read(networkServiceProvider);

      // Görsel önce yüklenir: ilan kaydı oluştuktan sonra yükleme
      // başarısız olursa görselsiz bir ilan kalırdı ve kullanıcı bunu
      // düzeltemezdi (ilan düzenleme ekranı yok).
      String? imagePath;
      if (_image != null) {
        imagePath = await service.uploadListingImage(
          bytes: _image!.bytes,
          fileName: _image!.name,
        );
      }

      await service.createListing(
        kind: widget.kind.code,
        title: _title.text,
        body: _body.text,
        clubId: widget.clubId,
        price: _isSale ? _parsedPrice : null,
        condition: _condition,
        imagePath: imagePath,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final field = isDark ? const Color(0xFF1A2537) : const Color(0xFFF4F7FA);

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle:
              jakarta(13, FontWeight.w500, SwanColors.textSecondary),
          filled: true,
          fillColor: field,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: kTeal),
          ),
        );

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 14),
          child: Text(text, style: jakarta(12, FontWeight.w700, ink)),
        );

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
                color: line, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),
          Text(widget.kind.label, style: sora(17, FontWeight.w800, ink)),

          label('Başlık'),
          TextField(
            controller: _title,
            style: jakarta(13.5, FontWeight.w600, ink),
            decoration: deco(
                _isSale ? '5 kulvar şamandırası' : 'İkinci el kürek arıyoruz'),
          ),

          if (_isSale) ...[
            label('Fiyat'),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: jakarta(13.5, FontWeight.w600, ink),
              decoration: deco('Boş bırakırsan "Pazarlıklı" görünür'),
            ),
          ],

          label('Durum'),
          Row(children: [
            for (final c in ListingCondition.values) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(
                      () => _condition = _condition == c ? null : c),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _condition == c ? kTeal : field,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _condition == c ? kTeal : line),
                    ),
                    child: Text(c.label,
                        style: jakarta(13, FontWeight.w700,
                            _condition == c ? Colors.white : ink)),
                  ),
                ),
              ),
              if (c != ListingCondition.values.last) const SizedBox(width: 10),
            ],
          ]),

          label('Açıklama'),
          TextField(
            controller: _body,
            maxLines: 3,
            style: jakarta(13.5, FontWeight.w600, ink),
            decoration: deco('Durumu, kaç yıllık, neden satılıyor…'),
          ),

          label('Fotoğraf'),
          GestureDetector(
            onTap: _busy ? null : _pick,
            child: Container(
              height: _image == null ? 52 : 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: line),
              ),
              clipBehavior: Clip.antiAlias,
              child: _image == null
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_a_photo_rounded,
                          size: 18, color: SwanColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('Fotoğraf ekle',
                          style: jakarta(13, FontWeight.w600,
                              SwanColors.textSecondary)),
                    ])
                  : Image.memory(_image!.bytes,
                      fit: BoxFit.cover, width: double.infinity),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!,
                style: jakarta(12, FontWeight.w600, const Color(0xFFD64545))),
          ],

          const SizedBox(height: 20),
          GestureDetector(
            onTap: _busy ? null : _submit,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: _busy
                    ? null
                    : const LinearGradient(colors: [kTealBright, kTeal]),
                color: _busy ? field : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Yayımla',
                      style: jakarta(14, FontWeight.w800, Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}
