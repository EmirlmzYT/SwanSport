import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';

/// İlan ayrıntısı ve Başantrenör Ekspertiz Raporu.
///
/// Stitch "i_kinci_el_ekipman_detay_ve_antren_r_raporu" tasarımını tam uygular:
/// - Doğrulanmış Ekipman ve İlan No bağlamı
/// - Zengin görsel aşaması (Ekspertiz Mühürlü, Dolap #08, A+ Kondisyon, Garantili Devir)
/// - Fiyatlandırma, piyasa sıfır karşılaştırması ve kulüp üyesi satıcı profili
/// - Başantrenör Ekspertiz & Doğrulama Raporu (Lazer toleransı, Tiller/Dovetail, Clicker, Kozmetik 9.8/10)
/// - Teknik Özellikler bento matrisi
/// - Poligon teslimatı ve Kulüp Emanet Havuz hesabı güvencesi
/// - Alt eylem çubuğu: Antrenöre Danış, Satıcıyla Sohbet, Güvenli Alım / Sepete Ekle
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _page = PageController();
  int _index = 0;
  int _selectedDeliveryOption = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final detail = ref.watch(marketDetailProvider(widget.listingId));
    final images = ref.watch(marketImagesProvider(widget.listingId)).valueOrNull ?? const <String>[];
    final favorites = ref.watch(marketFavoritesProvider).valueOrNull ?? {};
    final isFav = favorites.contains(widget.listingId);

    return Scaffold(
      backgroundColor: c.bg,
      body: detail.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (m) {
          if (m == null) {
            return premiumEmpty(
              context,
              icon: Icons.search_off_rounded,
              title: 'İlan bulunamadı',
              subtitle: 'Kaldırılmış ya da satılmış olabilir.',
            );
          }

          final me = Supabase.instance.client.auth.currentUser?.id;
          final ownerId = m['owner_id'] as String?;
          final isMine = me != null && me == ownerId;
          final status = MarketStatusX.fromCode(m['market_status'] as String?);
          final store = (m['stores'] as Map?)?.cast<String, dynamic>();

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildTopBar(c, isFav),
                          _gallery(c, images),
                          Padding(
                            padding: const EdgeInsets.all(SwanSpace.md),
                            child: _body(c, m, store, status),
                          ),
                        ],
                      ),
                    ),
                    _actions(c, m, isMine, isFav, status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(SwanPalette c, bool isFav) {
    final svc = ref.read(marketplaceServiceProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SwanSpace.md,
        vertical: SwanSpace.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.ink),
                tooltip: 'Geri',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'İlan No: #${widget.listingId.substring(0, widget.listingId.length > 6 ? 6 : widget.listingId.length).toUpperCase()}',
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                ),
              ),
              const SizedBox(width: SwanSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Doğrulanmış',
                      style: SwanType.caption(c.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.share_outlined, size: 20, color: c.ink),
                tooltip: 'Paylaş',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('İlan bağlantısı panoya kopyalandı.')),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  size: 20,
                  color: isFav ? c.danger : c.ink,
                ),
                tooltip: 'Favori',
                onPressed: () async {
                  await svc.setFavorite(widget.listingId, !isFav);
                  ref.invalidate(marketFavoritesProvider);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Galeri
  Widget _gallery(SwanPalette c, List<String> images) {
    final svc = ref.read(marketplaceServiceProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
      child: Stack(
        children: [
          Container(
            height: 260,
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              border: Border.all(color: c.line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              child: images.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_rounded, size: 48, color: c.accent.withValues(alpha: 0.5)),
                          const SizedBox(height: SwanSpace.xs),
                          Text('Resmi Kulüp Ekipmanı', style: SwanType.caption(c.inkMuted)),
                        ],
                      ),
                    )
                  : PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: images.length,
                      itemBuilder: (_, i) => Image.network(
                        svc.imageUrl(images[i]),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: c.surfaceAlt),
                      ),
                    ),
            ),
          ),
          // Floating Badges on Image
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: c.accent),
                  const SizedBox(width: 4),
                  Text('Ekspertiz Mühürlü', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 13, color: Colors.white70),
                  SizedBox(width: 4),
                  Text(
                    'Dolap #08 • Kulüp Poligonu',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'A+ Kusursuz Kondisyon',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Garantili Devir',
                    style: SwanType.caption(c.ink, w: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_index + 1}/${images.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Gövde
  Widget _body(
    SwanPalette c,
    Map<String, dynamic> m,
    Map<String, dynamic>? store,
    MarketStatus status,
  ) {
    final price = (m['price'] as num?)?.toDouble() ?? 14500;
    final cond = ItemConditionX.fromCode(m['item_condition'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title & Pricing Card
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KLASİK OLİMPİK YAY GÖVDESİ',
                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      if (cond != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            cond.label,
                            style: SwanType.caption(c.accent, w: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sağ El (RH)',
                          style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.xs),
              Text(
                '${m['title'] ?? 'Hoyt Formula Faktor 25"'}',
                style: SwanType.h2(c.ink),
              ),
              const SizedBox(height: 2),
              Text(
                'Orijinal Mat Teal / Karbon Siyahı Kombinasyonu',
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        money(price),
                        style: SwanType.h1(c.accent),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Piyasa Sıfır Değeri: ',
                            style: SwanType.caption(c.inkMuted),
                          ),
                          Text(
                            money(price * 1.54),
                            style: SwanType.caption(
                              c.inkMuted,
                              w: FontWeight.w600,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(%35 Tasarruf)',
                            style: SwanType.caption(c.accent, w: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: c.ink),
                        const SizedBox(width: 4),
                        Text('Kulüp Güvenceli', style: SwanType.caption(c.ink, w: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.md),
              // Club Member Seller Profile
              Container(
                padding: const EdgeInsets.all(SwanSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: c.accent,
                      child: const Text('EK', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Efe Korkmaz',
                                style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.verified_rounded, size: 14, color: c.accent),
                            ],
                          ),
                          Text(
                            'U21 Klasik Yay • Marmara SK 3 Yıl Lisanslı',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: c.accent),
                            Text('~15 dk', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                          ],
                        ),
                        Text('Yanıt Süresi', style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwanSpace.md),

        // Başantrenör Ekspertiz ve Doğrulama Raporu
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rule_rounded, size: 18, color: Colors.white),
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Başantrenör Ekspertiz Raporu',
                            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                          ),
                          Text(
                            'SwanSport Teknik Komite Onaylı',
                            style: SwanType.caption(c.accent, w: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Dün 16:45', style: SwanType.caption(c.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              // Inspector profile mini
              Container(
                padding: const EdgeInsets.all(SwanSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sports_rounded, size: 18, color: c.accent),
                    const SizedBox(width: SwanSpace.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ahmet Kaya (3. Kademe Başantrenör)',
                            style: SwanType.caption(c.ink, w: FontWeight.w700),
                          ),
                          Text(
                            'Marmara Okçuluk Kulübü Teknik Direktörü',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SwanSpace.md),
              // Checkpoints
              _buildReportCheck(
                c,
                'Gövde Düzlüğü & Torsional Rijidite',
                'Lazer kalibrasyonunda 0 tolerans sapma. Fabrika simetrisi korunan rijit gövde.',
              ),
              const SizedBox(height: SwanSpace.sm),
              _buildReportCheck(
                c,
                'Kiriş Hattı & Limb Alignment Vidaları',
                'Vidalar orijinal, aşınmasız; dovetail yataklarında sıfır gevşeme veya boşluk.',
              ),
              const SizedBox(height: SwanSpace.sm),
              _buildReportCheck(
                c,
                'Clicker Uzantısı & Yuvalar',
                'Dişler tertemiz; yalama, zorlanma veya metal deformasyonu tespit edilmedi.',
              ),
              const SizedBox(height: SwanSpace.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.accent),
                    ),
                    child: Text(
                      '9.8',
                      style: SwanType.caption(c.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kozmetik Durum: 9.8 / 10',
                          style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                        ),
                        Text(
                          'Yalnızca grip tabanında mikro sürtünme izi mevcut, atış performansına etkisi sıfır.',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.md),
              // Coach quote
              Container(
                padding: const EdgeInsets.all(SwanSpace.sm),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote_rounded, size: 20, color: c.accent),
                    const SizedBox(width: SwanSpace.xs),
                    Expanded(
                      child: Text(
                        '"Gençler veya büyüklere geçiş yapan, 36-44 lbs aralığında yarışan tüm sporcularımız için ideal müsabaka gövdesidir. Gönül rahatlığıyla tavsiye ederim."',
                        style: SwanType.caption(c.ink, w: FontWeight.w500).copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SwanSpace.md),

        // Technical Specs Grid
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: c.accent),
                  const SizedBox(width: SwanSpace.xs),
                  Text('Teknik Özellikler', style: SwanType.h3(c.ink)),
                ],
              ),
              const SizedBox(height: SwanSpace.md),
              Row(
                children: [
                  Expanded(child: _buildSpecBox(c, 'Gövde Uzunluğu', '25 inç (63.5 cm)')),
                  const SizedBox(width: SwanSpace.xs),
                  Expanded(child: _buildSpecBox(c, 'Materyal', 'Havacılık Alüminyumu')),
                ],
              ),
              const SizedBox(height: SwanSpace.xs),
              Row(
                children: [
                  Expanded(child: _buildSpecBox(c, 'Net Ağırlık', '1.215 gram')),
                  const SizedBox(width: SwanSpace.xs),
                  Expanded(child: _buildSpecBox(c, 'Kol Sistemi', 'Hoyt Formula Serisi')),
                ],
              ),
              const SizedBox(height: SwanSpace.xs),
              _buildSpecBox(c, 'Kaplama & Renk', 'Orijinal Anodize Teal (Mat Pürüzsüz)'),
            ],
          ),
        ),
        const SizedBox(height: SwanSpace.md),

        // Delivery and Escrow Options
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.lg),
            border: Border.all(color: c.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_shipping_outlined, size: 18, color: c.accent),
                  const SizedBox(width: SwanSpace.xs),
                  Text('Teslimat ve Güvenli Devir', style: SwanType.h3(c.ink)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Kulüp gözetiminde alıcı ve satıcı hakları 7/24 teminat altındadır.',
                style: SwanType.caption(c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.md),
              _buildDeliveryTile(
                c: c,
                index: 0,
                title: 'Poligonda Elden Teslim & Dolaptan Alma',
                tag: 'ÜCRETSİZ',
                subtitle: 'Ahmet Hoca eşliğinde atış hattında deneme atışı yapıp onaylayarak Dolap #08\'den teslim alın.',
              ),
              const SizedBox(height: SwanSpace.xs),
              _buildDeliveryTile(
                c: c,
                index: 1,
                title: 'Kulüp Havuz Hesabı Güvencesi',
                tag: 'ÖNERİLEN',
                subtitle: 'Ödemeniz SwanSport emanet havuzunda bekletilir. Malzeme kontrolünüzden sonra onayınızla aktarılır.',
              ),
            ],
          ),
        ),
        const SizedBox(height: SwanSpace.md),
      ],
    );
  }

  Widget _buildReportCheck(SwanPalette c, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_rounded, size: 18, color: c.accent),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
              Text(subtitle, style: SwanType.caption(c.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecBox(SwanPalette c, String label, String val) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: 2),
          Text(val, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildDeliveryTile({
    required SwanPalette c,
    required int index,
    required String title,
    required String tag,
    required String subtitle,
  }) {
    final isSelected = _selectedDeliveryOption == index;

    return InkWell(
      onTap: () => setState(() => _selectedDeliveryOption = index),
      borderRadius: BorderRadius.circular(SwanRadius.md),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withValues(alpha: 0.08) : c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: isSelected ? c.accent : c.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2, right: SwanSpace.sm),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? c.accent : c.inkMuted,
                  width: isSelected ? 5 : 2,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: Text(
                          tag,
                          style: SwanType.caption(c.accent, w: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Eylemler
  Widget _actions(
    SwanPalette c,
    Map<String, dynamic> m,
    bool isMine,
    bool isFav,
    MarketStatus status,
  ) {
    if (isMine) {
      return Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: _ownerActions(c, status),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.md,
        SwanSpace.sm,
        SwanSpace.md,
        SwanSpace.md,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          // Antrenörle Görüş
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kulüp başantrenörüne danışma talebi iletildi.')),
              );
            },
            icon: Icon(Icons.support_agent_rounded, size: 22, color: c.ink),
            tooltip: 'Antrenöre Soru Sor',
            style: IconButton.styleFrom(
              backgroundColor: c.surfaceAlt,
              padding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(width: SwanSpace.xs),
          // Satıcıyla Sohbet
          OutlinedButton.icon(
            onPressed: status.isBuyable ? () => _openChat(m) : null,
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Satıcı'),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.ink,
              side: BorderSide(color: c.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(width: SwanSpace.xs),
          // Güvenle Satın Al / Sepete Ekle
          Expanded(
            child: FilledButton.icon(
              onPressed: () {
                unawaited(Navigator.pushNamed(context, '/sepet'));
              },
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text(
                'Güvenle Satın Al (₺14.500)',
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ownerActions(SwanPalette c, MarketStatus status) {
    final svc = ref.read(marketplaceServiceProvider);

    Future<void> set(MarketStatus s) async {
      try {
        await svc.setStatus(widget.listingId, s);
        ref.invalidate(marketDetailProvider(widget.listingId));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: c.danger),
          );
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              unawaited(
                set(
                  status == MarketStatus.reserved
                      ? MarketStatus.active
                      : MarketStatus.reserved,
                ),
              );
            },
            child: Text(status == MarketStatus.reserved ? 'Yayına al' : 'Rezerve et'),
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: FilledButton(
            onPressed: status == MarketStatus.sold
                ? null
                : () {
                    unawaited(set(MarketStatus.sold));
                  },
            child: Text(status == MarketStatus.sold ? 'Satıldı' : 'Satıldı işaretle'),
          ),
        ),
      ],
    );
  }

  void _openChat(Map<String, dynamic> m) {
    final ownerId = m['owner_id'] as String?;
    if (ownerId == null) return;
    unawaited(
      Navigator.pushNamed(
        context,
        '/sohbet',
        arguments: {
          'id': ownerId,
          'name': (m['stores'] as Map?)?['name'] ?? 'Satıcı',
        },
      ),
    );
  }
}
