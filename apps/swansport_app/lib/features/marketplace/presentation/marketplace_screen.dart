import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_chip.dart';

/// Spor Malzemeleri Pazaryeri.
///
/// **Alt gezinmeye eklenmiyor.** Beş sekme kalıyor; pazaryeri Keşfet üzerinden
/// açılıyor. Altıncı sekme, günlük kullanılan dört şeyin (ana sayfa, keşfet,
/// mesaj, profil) yanına ayda bir kullanılacak bir şey koymak olurdu.
///
/// İlk sürümde ödeme yok: alıcı ve satıcı mevcut sohbetle anlaşıyor. Ekran
/// ilan, filtre ve durum gösteriyor; satın alma düğmesi bilinçli olarak yok —
/// olsaydı uygulama içinde ödeme varmış gibi bir beklenti yaratırdı.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  MarketFilter _filter = const MarketFilter();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final results = ref.watch(marketSearchProvider(_filter));
    final favorites = ref.watch(marketFavoritesProvider).valueOrNull ?? {};

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              _header(context, c),
              _searchBar(c),
              const SizedBox(height: SwanSpace.sm),
              _filters(c),
              const SizedBox(height: SwanSpace.md),
              Expanded(
                child: results.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (items) => items.isEmpty
                      ? _empty(context)
                      : RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(marketSearchProvider(_filter));
                            await ref
                                .read(marketSearchProvider(_filter).future);
                          },
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                SwanSpace.lg, 0, SwanSpace.lg, 132),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: SwanSpace.md,
                              crossAxisSpacing: SwanSpace.md,
                              childAspectRatio: .72,
                            ),
                            itemCount: items.length,
                            itemBuilder: (_, i) => _card(
                                context, c, items[i],
                                favorites.contains(items[i].id)),
                          ),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // ------------------------------------------------------------- parçalar

  Widget _header(BuildContext context, SwanPalette c) => Padding(
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
          Expanded(child: Text('Pazaryeri', style: SwanType.h2(c.ink))),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/ilan-ver'),
            child: Container(
              height: 38,
              padding:
                  const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                // Üstünde beyaz metin var: `accent` değil `accentFill`.
                color: c.accentFill,
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Text('İlan ver',
                  style: SwanType.caption(Colors.white, w: FontWeight.w800)),
            ),
          ),
        ]),
      );

  Widget _searchBar(SwanPalette c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
          decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.line)),
          child: Row(children: [
            Icon(Icons.search_rounded, size: 18, color: c.inkMuted),
            const SizedBox(width: SwanSpace.sm),
            Expanded(
              child: TextField(
                controller: _search,
                style: SwanType.bodySm(c.ink),
                textInputAction: TextInputAction.search,
                // Aramayı her harfte değil onaylayınca çalıştırıyoruz:
                // her tuşta sunucuya gitmek hem yavaş hem gereksiz.
                onSubmitted: (v) => setState(
                    () => _filter = _filter.copyWith(query: v.trim())),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Krampon, raket, forma…',
                  hintStyle: SwanType.bodySm(c.inkMuted),
                ),
              ),
            ),
            if (!_filter.isEmpty)
              GestureDetector(
                onTap: () {
                  _search.clear();
                  setState(() => _filter = const MarketFilter());
                },
                child: Icon(Icons.close_rounded, size: 18, color: c.inkMuted),
              ),
          ]),
        ),
      );

  Widget _filters(SwanPalette c) => SwanChipBar(children: [
        SwanChip(
          label: 'Sıfır',
          selected: _filter.condition == ItemCondition.isNew,
          onTap: () => setState(() => _filter = _filter.copyWith(
              condition: _filter.condition == ItemCondition.isNew
                  ? null
                  : ItemCondition.isNew)),
        ),
        SwanChip(
          label: 'İkinci el',
          selected: _filter.sellerType == 'individual',
          onTap: () => setState(() => _filter = _filter.copyWith(
              sellerType:
                  _filter.sellerType == 'individual' ? null : 'individual')),
        ),
        SwanChip(
          label: 'Mağaza',
          selected: _filter.sellerType == 'verified_store',
          onTap: () => setState(() => _filter = _filter.copyWith(
              sellerType: _filter.sellerType == 'verified_store'
                  ? null
                  : 'verified_store')),
        ),
        SwanChip(
          label: 'Kargo',
          icon: Icons.local_shipping_rounded,
          selected: _filter.delivery == DeliveryKind.shipping,
          onTap: () => setState(() => _filter = _filter.copyWith(
              delivery: _filter.delivery == DeliveryKind.shipping
                  ? null
                  : DeliveryKind.shipping)),
        ),
        SwanChip(
          label: 'Ucuzdan',
          selected: _filter.sort == 'price_asc',
          onTap: () => setState(() => _filter = _filter.copyWith(
              sort: _filter.sort == 'price_asc' ? 'new' : 'price_asc')),
        ),
        SwanChip(
          label: 'Pahalıdan',
          selected: _filter.sort == 'price_desc',
          onTap: () => setState(() => _filter = _filter.copyWith(
              sort: _filter.sort == 'price_desc' ? 'new' : 'price_desc')),
        ),
      ]);

  Widget _empty(BuildContext context) => premiumEmpty(
        context,
        icon: _filter.isEmpty
            ? Icons.storefront_rounded
            : Icons.filter_alt_off_rounded,
        title: _filter.isEmpty ? 'Henüz ilan yok' : 'Sonuç yok',
        subtitle: _filter.isEmpty
            ? 'İlk ilanı sen ver — kullanılmayan malzemen varsa buradan '
                'değerlendirebilirsin.'
            : 'Aramayı veya filtreleri değiştirip tekrar dene.',
      );

  Widget _card(
      BuildContext context, SwanPalette c, MarketItem it, bool isFav) {
    final svc = ref.read(marketplaceServiceProvider);
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/urun', arguments: {'id': it.id}),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              if (it.imagePath != null)
                Image.network(svc.imageUrl(it.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _noImage(c))
              else
                _noImage(c),

              // Rezerve ve satıldı ilan aramada görünüyor ama satın
              // alınabilir gibi durmamalı; etiket bunu söylüyor.
              if (it.status != MarketStatus.active)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: .62),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(it.status.label,
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w800)),
                  ),
                ),

              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () async {
                    await svc.setFavorite(it.id, !isFav);
                    ref.invalidate(marketFavoritesProvider);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 15,
                        color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(SwanSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(it.price == null ? 'Fiyat yok' : money(it.price!),
                    style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(children: [
                  if (it.isStore) ...[
                    Icon(Icons.verified_rounded, size: 12, color: c.accent),
                    const SizedBox(width: 3),
                  ],
                  Expanded(
                    child: Text(
                        it.isStore
                            ? (it.storeName ?? 'Mağaza')
                            : (it.condition?.label ?? 'İkinci el'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted)),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _noImage(SwanPalette c) => Container(
        color: c.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.image_not_supported_rounded,
            size: 26, color: c.inkMuted),
      );
}
