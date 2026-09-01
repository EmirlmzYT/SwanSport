import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';

/// İlan ayrıntısı.
///
/// Satın alma düğmesi **yok**. İlk sürümde ödeme alınmıyor; alıcı satıcıyla
/// sohbet açıp anlaşıyor. "Satın al" koymak, uygulama içinde ödeme varmış
/// gibi bir beklenti yaratır ve para bir yerde takıldığında sorumluluk
/// bizde sanılır.
class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final detail = ref.watch(marketDetailProvider(widget.listingId));
    final images = ref.watch(marketImagesProvider(widget.listingId)).valueOrNull
        ?? const <String>[];
    final favorites = ref.watch(marketFavoritesProvider).valueOrNull ?? {};
    final isFav = favorites.contains(widget.listingId);

    return Scaffold(
      backgroundColor: c.bg,
      body: detail.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (m) {
          if (m == null) {
            return premiumEmpty(context,
                icon: Icons.search_off_rounded,
                title: 'İlan bulunamadı',
                subtitle: 'Kaldırılmış ya da satılmış olabilir.');
          }

          final me = Supabase.instance.client.auth.currentUser?.id;
          final ownerId = m['owner_id'] as String?;
          final isMine = me != null && me == ownerId;
          final status = MarketStatusX.fromCode(m['market_status'] as String?);
          final store = (m['stores'] as Map?)?.cast<String, dynamic>();

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _gallery(c, images),
                        Padding(
                          padding: const EdgeInsets.all(SwanSpace.lg),
                          child: _body(c, m, store, status),
                        ),
                      ],
                    ),
                  ),
                  _actions(c, m, isMine, isFav, status),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------------------- galeri

  Widget _gallery(SwanPalette c, List<String> images) {
    final svc = ref.read(marketplaceServiceProvider);
    return Stack(children: [
      SizedBox(
        height: 300,
        child: images.isEmpty
            ? Container(
                color: c.surfaceAlt,
                alignment: Alignment.center,
                child: Icon(Icons.image_not_supported_rounded,
                    size: 40, color: c.inkMuted),
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
      Positioned(
        top: SwanSpace.md,
        left: SwanSpace.md,
        child: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .45),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: Colors.white),
          ),
        ),
      ),
      if (images.length > 1)
        Positioned(
          bottom: SwanSpace.md,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < images.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: i == _index ? 1 : .5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
    ]);
  }

  // ---------------------------------------------------------------- gövde

  Widget _body(SwanPalette c, Map<String, dynamic> m,
      Map<String, dynamic>? store, MarketStatus status) {
    final price = (m['price'] as num?)?.toDouble();
    final cond = ItemConditionX.fromCode(m['item_condition'] as String?);
    final delivery = DeliveryKindX.fromCode(m['delivery'] as String?);
    final specs = <(String, String?)>[
      ('Marka', m['brand'] as String?),
      ('Model', m['model'] as String?),
      ('Beden', m['size_label'] as String?),
      ('Renk', m['color'] as String?),
      ('Kategori', m['subcategory'] as String? ?? m['category'] as String?),
    ].where((e) => (e.$2 ?? '').isNotEmpty).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (status != MarketStatus.active) ...[
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md, vertical: 6),
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(SwanRadius.sm),
          ),
          child: Text(status.label,
              style: SwanType.caption(c.warning, w: FontWeight.w800)),
        ),
        const SizedBox(height: SwanSpace.md),
      ],

      Text('${m['title']}', style: SwanType.h2(c.ink)),
      const SizedBox(height: SwanSpace.xs),
      Row(children: [
        Text(price == null ? 'Fiyat belirtilmemiş' : money(price),
            style: SwanType.h3(c.accent)),
        if (m['negotiable'] == true) ...[
          const SizedBox(width: SwanSpace.sm),
          Text('· pazarlık olur', style: SwanType.caption(c.inkMuted)),
        ],
      ]),

      const SizedBox(height: SwanSpace.lg),
      Row(children: [
        if (store != null) ...[
          Icon(Icons.verified_rounded, size: 16, color: c.accent),
          const SizedBox(width: 5),
          Text('${store['name']}',
              style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
        ] else
          Text('Bireysel satıcı',
              style: SwanType.bodySm(c.inkMuted, w: FontWeight.w600)),
        const Spacer(),
        if (cond != null)
          Text(cond.label, style: SwanType.caption(c.inkMuted)),
      ]),

      const SizedBox(height: SwanSpace.lg),
      _row(c, Icons.local_shipping_rounded, delivery.label),
      if (((m['district'] ?? m['city_code']) ?? '').toString().isNotEmpty)
        _row(c, Icons.place_rounded,
            [m['district'], m['city_code']].where((e) => e != null).join(', ')),
      if ((m['stock'] as int?) != null && (m['stock'] as int) > 1)
        _row(c, Icons.inventory_2_rounded, '${m['stock']} adet'),

      if (((m['body'] ?? '') as String).isNotEmpty) ...[
        const SizedBox(height: SwanSpace.lg),
        Text('${m['body']}', style: SwanType.bodySm(c.ink)),
      ],

      // Kusur açıklaması ayrı ve görünür: ikinci el üründe alıcının en çok
      // bilmek istediği şey bu ve açıklamanın içine gömülünce kayboluyor.
      if (((m['defect_note'] ?? '') as String).isNotEmpty) ...[
        const SizedBox(height: SwanSpace.lg),
        Container(
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: c.warning.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(SwanRadius.sm),
            border: Border(left: BorderSide(color: c.warning, width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kusur / aşınma',
                style: SwanType.caption(c.ink, w: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${m['defect_note']}', style: SwanType.caption(c.inkMuted)),
          ]),
        ),
      ],

      if (specs.isNotEmpty) ...[
        const SizedBox(height: SwanSpace.xl),
        Text('Özellikler', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        for (final s in specs)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              SizedBox(
                  width: 90,
                  child: Text(s.$1, style: SwanType.caption(c.inkMuted))),
              Expanded(
                  child: Text(s.$2!,
                      style: SwanType.caption(c.ink, w: FontWeight.w600))),
            ]),
          ),
      ],

      const SizedBox(height: SwanSpace.xl),
      // Güvenli alışveriş uyarısı. Kısa tutuldu: uzun uyarı okunmuyor ve
      // okunmayan uyarı, olmayan uyarıdan farksız.
      Container(
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Güvenli alışveriş',
              style: SwanType.caption(c.ink, w: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(
            '· Açık adresini herkese paylaşma\n'
            '· Uygulama dışı ödeme yönlendirmelerine dikkat et\n'
            '· Teslimde ürünü kontrol et',
            style: SwanType.caption(c.inkMuted),
          ),
        ]),
      ),
      const SizedBox(height: SwanSpace.lg),
    ]);
  }

  Widget _row(SwanPalette c, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(icon, size: 15, color: c.inkMuted),
          const SizedBox(width: SwanSpace.sm),
          Expanded(child: Text(text, style: SwanType.bodySm(c.ink))),
        ]),
      );

  // -------------------------------------------------------------- eylemler

  Widget _actions(SwanPalette c, Map<String, dynamic> m, bool isMine,
      bool isFav, MarketStatus status) {
    final svc = ref.read(marketplaceServiceProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(children: [
        if (!isMine) ...[
          _iconBtn(
            c,
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            () async {
              await svc.setFavorite(widget.listingId, !isFav);
              ref.invalidate(marketFavoritesProvider);
            },
            tint: isFav ? c.danger : null,
          ),
          const SizedBox(width: SwanSpace.sm),
          _iconBtn(c, Icons.flag_outlined, () => _report(c)),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: GestureDetector(
              onTap: status.isBuyable ? () => _openChat(m) : null,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status.isBuyable ? c.accentFill : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
                child: Text(
                    status.isBuyable
                        ? 'Satıcıya yaz'
                        : 'Bu ilan ${status.label.toLowerCase()}',
                    style: SwanType.bodySm(
                        status.isBuyable ? Colors.white : c.inkMuted,
                        w: FontWeight.w800)),
              ),
            ),
          ),
        ] else
          Expanded(child: _ownerActions(c, status)),
      ]),
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
              SnackBar(content: Text('$e'), backgroundColor: c.danger));
        }
      }
    }

    return Row(children: [
      Expanded(
        child: _outlined(c, status == MarketStatus.reserved ? 'Yayına al' : 'Rezerve et',
            () => set(status == MarketStatus.reserved
                ? MarketStatus.active
                : MarketStatus.reserved)),
      ),
      const SizedBox(width: SwanSpace.sm),
      Expanded(
        child: GestureDetector(
          onTap: status == MarketStatus.sold ? null : () => set(MarketStatus.sold),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: status == MarketStatus.sold ? c.surfaceAlt : c.successFill,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Text(
                status == MarketStatus.sold ? 'Satıldı' : 'Satıldı işaretle',
                style: SwanType.bodySm(
                    status == MarketStatus.sold ? c.inkMuted : Colors.white,
                    w: FontWeight.w800)),
          ),
        ),
      ),
    ]);
  }

  Widget _outlined(SwanPalette c, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Text(label,
              style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
        ),
      );

  Widget _iconBtn(SwanPalette c, IconData icon, VoidCallback onTap,
          {Color? tint}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border.all(color: c.line),
          ),
          child: Icon(icon, size: 19, color: tint ?? c.ink),
        ),
      );

  /// Satıcıyla sohbet — **yeni bir mesajlaşma sistemi kurulmuyor**, mevcut
  /// DM akışı kullanılıyor. İlan bağlamı ilk mesajla taşınıyor.
  void _openChat(Map<String, dynamic> m) {
    final ownerId = m['owner_id'] as String?;
    if (ownerId == null) return;
    Navigator.pushNamed(context, '/sohbet', arguments: {
      'id': ownerId,
      'name': (m['stores'] as Map?)?['name'] ?? 'Satıcı',
    });
  }

  Future<void> _report(SwanPalette c) async {
    final reason = await showModalBottomSheet<ReportReason>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: SwanSpace.lg),
          Text('İlanı bildir', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.md),
          for (final r in ReportReason.values)
            ListTile(
              title: Text(r.label, style: SwanType.bodySm(c.ink)),
              onTap: () => Navigator.pop(ctx, r),
            ),
          const SizedBox(height: SwanSpace.md),
        ]),
      ),
    );
    if (reason == null || !mounted) return;

    try {
      await ref.read(marketplaceServiceProvider).report(widget.listingId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Bildirildi, teşekkürler'),
            backgroundColor: c.accentFill));
      }
    } catch (e) {
      // Aynı ilanı ikinci kez raporlamak benzersizlik kısıtına takılıyor.
      // Kullanıcıya ham hata göstermek yerine ne olduğunu söylüyoruz.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Bu ilanı zaten bildirmişsin'),
            backgroundColor: c.inkMuted));
      }
    }
  }
}
