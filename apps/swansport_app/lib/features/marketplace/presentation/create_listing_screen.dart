import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_chip.dart';

/// Pazaryeri ilanı oluşturma.
///
/// Tek sayfa, bölümlü. Plandaki altı adım **sihirbaz değil bölüm** olarak
/// kuruldu: altı ekran arasında ileri geri gitmek, dördüncü adımda ikinci
/// adımı düzeltmek isteyen kullanıcıyı yoruyor. Alanların hepsi burada,
/// sırayla; yayınla düğmesi altta.
///
/// Kurallar istemcide **gösteriliyor**, sunucuda **zorlanıyor** (0051).
/// Buradaki kontroller kullanıcıya sebebini anlatmak için; güvenlik değil.
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _size = TextEditingController();
  final _color = TextEditingController();
  final _price = TextEditingController();
  final _defect = TextEditingController();
  final _category = TextEditingController();

  ItemCondition _condition = ItemCondition.good;
  DeliveryKind _delivery = DeliveryKind.hand;
  bool _negotiable = false;
  StoreRow? _store;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _body, _brand, _model, _size, _color, _price,
                     _defect, _category]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final stores = ref.watch(myStoresProvider).valueOrNull ?? const <StoreRow>[];
    final approved = stores.where((s) => s.isApproved).toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              _header(c),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.xl),
                  children: [
                    _sellerSection(c, approved),
                    _section(c, 'Ürün'),
                    _field(c, _title, 'Başlık', 'Nike Mercurial krampon'),
                    _field(c, _category, 'Kategori', 'Ayakkabı, forma, raket…'),
                    Row(children: [
                      Expanded(child: _field(c, _brand, 'Marka', 'Nike')),
                      const SizedBox(width: SwanSpace.md),
                      Expanded(child: _field(c, _model, 'Model', 'Vapor 15')),
                    ]),
                    Row(children: [
                      Expanded(child: _field(c, _size, 'Beden', '42')),
                      const SizedBox(width: SwanSpace.md),
                      Expanded(child: _field(c, _color, 'Renk', 'Siyah')),
                    ]),

                    _section(c, 'Durum'),
                    _conditionPicker(c, approved.isNotEmpty),
                    _field(c, _defect, 'Kusur / aşınma',
                        'Taban aşınmış, dış yüzeyde çizik var',
                        lines: 2),
                    // Kusur alanı zorunlu değil ama öne çıkarılıyor: ikinci
                    // elde alıcının en çok bilmek istediği şey bu ve
                    // yazılmadığında satış sohbette tıkanıyor.

                    _section(c, 'Fiyat ve teslim'),
                    _field(c, _price, 'Fiyat (₺)', '1500',
                        keyboard: TextInputType.number),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _negotiable,
                      activeThumbColor: c.accent,
                      onChanged: (v) => setState(() => _negotiable = v),
                      title: Text('Pazarlık olur',
                          style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                    ),
                    _deliveryPicker(c),

                    _section(c, 'Açıklama'),
                    _field(c, _body, 'Açıklama',
                        'Ürün hakkında bilmek istenecekler', lines: 4),

                    const SizedBox(height: SwanSpace.lg),
                    // Görsel yükleme ayrı bir adım: ilan oluşturulmadan
                    // görselin bağlanacağı bir kimlik yok. İlan
                    // yayınlandıktan sonra detay ekranından ekleniyor.
                    Container(
                      padding: const EdgeInsets.all(SwanSpace.md),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(SwanRadius.sm),
                      ),
                      child: Text(
                        'Görselleri ilan oluşturulduktan sonra ekleyebilirsin '
                        '— en fazla 8 tane.',
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ),
              _submit(c, approved),
            ]),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- parçalar

  Widget _header(SwanPalette c) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.md),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  border: Border.all(color: c.line)),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: c.ink),
            ),
          ),
          const SizedBox(width: SwanSpace.md),
          Text('İlan ver', style: SwanType.h2(c.ink)),
        ]),
      );

  Widget _sellerSection(SwanPalette c, List<StoreRow> approved) {
    if (approved.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        margin: const EdgeInsets.only(bottom: SwanSpace.sm),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('İkinci el ürün satıyorsun',
              style: SwanType.caption(c.ink, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            'Sıfır ürün yalnızca onaylı mağazalar tarafından satılabilir. '
            'Mağaza açmak istersen başvurabilirsin.',
            style: SwanType.caption(c.inkMuted),
          ),
          const SizedBox(height: SwanSpace.sm),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/magaza-basvuru'),
            child: Text('Mağaza başvurusu →',
                style: SwanType.caption(c.accent, w: FontWeight.w800)),
          ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(c, 'Satıcı'),
      Wrap(spacing: SwanSpace.sm, runSpacing: SwanSpace.sm, children: [
        SwanChip(
          label: 'Bireysel',
          selected: _store == null,
          onTap: () => setState(() {
            _store = null;
            if (_condition == ItemCondition.isNew) {
              _condition = ItemCondition.good;
            }
          }),
        ),
        for (final s in approved)
          SwanChip(
            label: s.name,
            icon: Icons.verified_rounded,
            selected: _store?.id == s.id,
            onTap: () => setState(() => _store = s),
          ),
      ]),
    ]);
  }

  Widget _conditionPicker(SwanPalette c, bool hasStore) => Wrap(
        spacing: SwanSpace.sm,
        runSpacing: SwanSpace.sm,
        children: [
          for (final k in ItemCondition.values)
            // "Sıfır" yalnızca mağaza seçiliyken görünüyor. Gösterip
            // tıklanınca hata vermek, kuralı hata mesajıyla öğretmek olurdu.
            if (k != ItemCondition.isNew || _store != null)
              SwanChip(
                label: k.label,
                selected: _condition == k,
                onTap: () => setState(() => _condition = k),
              ),
        ],
      );

  Widget _deliveryPicker(SwanPalette c) => Padding(
        padding: const EdgeInsets.only(top: SwanSpace.sm),
        child: Wrap(
          spacing: SwanSpace.sm,
          children: [
            for (final d in DeliveryKind.values)
              SwanChip(
                label: d.label,
                selected: _delivery == d,
                onTap: () => setState(() => _delivery = d),
              ),
          ],
        ),
      );

  Widget _section(SwanPalette c, String title) => Padding(
        padding: const EdgeInsets.only(top: SwanSpace.xl, bottom: SwanSpace.sm),
        child: Text(title, style: SwanType.h3(c.ink)),
      );

  Widget _field(SwanPalette c, TextEditingController ctrl, String label,
          String hint,
          {int lines = 1, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.md),
        child: TextField(
          controller: ctrl,
          minLines: lines,
          maxLines: lines,
          keyboardType: keyboard,
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: SwanType.caption(c.inkMuted),
            hintText: hint,
            hintStyle: SwanType.caption(c.inkMuted),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.md, vertical: SwanSpace.md),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                borderSide: BorderSide(color: c.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
      );

  Widget _submit(SwanPalette c, List<StoreRow> approved) => Container(
        padding: const EdgeInsets.fromLTRB(
            SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: GestureDetector(
          onTap: _saving ? null : _publish,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accentFill,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Text(_saving ? 'Yayınlanıyor…' : 'Yayınla',
                style: SwanType.body(Colors.white, w: FontWeight.w800)),
          ),
        ),
      );

  Future<void> _publish() async {
    final c = context.swan;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Başlık gerekli'), backgroundColor: c.danger));
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(marketplaceServiceProvider).create(
            title: _title.text,
            body: _body.text,
            storeId: _store?.id,
            category: _category.text.trim().isEmpty ? null : _category.text.trim(),
            brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
            model: _model.text.trim().isEmpty ? null : _model.text.trim(),
            size: _size.text.trim().isEmpty ? null : _size.text.trim(),
            color: _color.text.trim().isEmpty ? null : _color.text.trim(),
            condition: _condition,
            defectNote: _defect.text,
            price: double.tryParse(_price.text.replaceAll(',', '.')),
            negotiable: _negotiable,
            delivery: _delivery,
          );

      if (!mounted) return;
      // Yayınlanan ilana gidiliyor: kullanıcı sonucu görsün ve görselini
      // oradan ekleyebilsin.
      Navigator.pushReplacementNamed(context, '/urun', arguments: {'id': id});
    } catch (e) {
      if (mounted) {
        // Sunucudaki kurallar (hız sınırı, doğrulama, mağaza onayı) buradan
        // dönüyor. Ham hata yerine mesajın kendisi gösteriliyor; RPC'ler
        // Türkçe ve anlaşılır mesaj veriyor.
        final msg = '$e'.contains('exception')
            ? '$e'.split('exception').last.replaceAll(RegExp(r'^[:,\s]+'), '')
            : '$e';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: c.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
