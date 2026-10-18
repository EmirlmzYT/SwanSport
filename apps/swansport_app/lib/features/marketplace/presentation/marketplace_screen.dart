import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/widgets/swan_tabs.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/stitch_components.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Spor Malzemeleri & Kulüp Resmi Mağazası (Stitch Redesign).
/// Hem Resmi Kulüp Ürünleri hem de Kulüp İçi Doğrulanmış İkinci El Pazarı.
class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  final _search = TextEditingController();
  MarketFilter _filter = const MarketFilter();
  int _storeSection = 0; // 0 = Tüm Ürünler & Resmi Mağaza, 1 = 2. El Pazarı

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final results = ref.watch(marketSearchProvider(_filter));
    final favorites = ref.watch(marketFavoritesProvider).valueOrNull ?? {};

    return SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Pazaryeri', actions: [
        TextButton.icon(onPressed: () => Navigator.pushNamed(context, '/ilan-ver'), icon: Icon(Icons.add_box_outlined), label: Text('İlan Ver', style: SwanType.caption(context.swan.accent))),
      ]),
      extendBody: true,
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(marketSearchProvider(_filter));
                await ref.read(marketSearchProvider(_filter).future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.xs, SwanSpace.lg, SwanSpace.xl * 5),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: SwanSpace.md),
                    child: SwanSegmentedTabs(labels: const ['Resmi Mağaza', 'Kulüp İçi 2. El'],
                      selected: _storeSection, onSelect: (i) => setState(() {
                        _storeSection = i;
                        _filter = _filter.copyWith(sellerType: i == 0 ? null : 'individual');
                      })),
                  ),

                  // 2. Search & Filter Bar
                  _buildSearchBar(palette),
                  const SizedBox(height: 12),

                  // 4. Featured Banner based on mode
                  if (_storeSection == 0)
                    _buildOfficialHeroBanner(palette, isDark)
                  else
                    _buildCoachGuaranteeBanner(palette, isDark),
                  const SizedBox(height: 14),

                  // 5. Club Delivery Info Strip

                  // 6. Category Filter Pills
                  _buildCategoryPills(palette),
                  const SizedBox(height: 14),

                  // 7. Products Section Header & Grid
                  _buildProductsHeader(palette),
                  const SizedBox(height: 10),

                  results.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (items) {
                      var filtered = items;
                      if (_storeSection == 1) {
                        filtered = items.where((it) => !it.isStore).toList();
                      }
                      if (filtered.isEmpty) {
                        return _buildEmpty(context, palette);
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildProductCard(
                          context,
                          palette,
                          isDark,
                          filtered[i],
                          favorites.contains(filtered[i].id),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // --- Top Bar ---


  // --- Search Bar ---
  Widget _buildSearchBar(SwanPalette palette) {
    return StitchInlineSearchField(
      controller: _search,
      hint: 'Forma, yay gövdesi, ok seti, aksesuar ara…',
      onChanged: (v) {
        if (v.isEmpty && (_filter.query ?? '').isNotEmpty) {
          setState(() => _filter = _filter.copyWith(query: null));
        } else {
          setState(() {});
        }
      },
      onSubmitted: (v) => setState(
        () => _filter = _filter.copyWith(query: v.trim()),
      ),
    );
  }

  // --- Section Tabs ---
  Widget _buildOfficialHeroBanner(SwanPalette palette, bool isDark) => Container(
    padding: const EdgeInsets.all(SwanSpace.lg),
    decoration: BoxDecoration(color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Mağaza ilanları', style: SwanType.h3(palette.ink)),
      const SizedBox(height: SwanSpace.sm),
      Text('Ürün, fiyat ve teslimat bilgilerini ilanın ayrıntılarında incele.',
          style: SwanType.bodySm(palette.inkMuted)),
    ]),
  );

  // --- Coach Guarantee Banner for Used Market ---
  Widget _buildCoachGuaranteeBanner(SwanPalette palette, bool isDark) => Container(
    padding: const EdgeInsets.all(SwanSpace.lg),
    decoration: BoxDecoration(color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('İkinci el ekipmanlar', style: SwanType.h3(palette.ink)),
      const SizedBox(height: SwanSpace.sm),
      Text('Ürünün durumunu ve teslimat koşullarını satıcıyla görüşerek doğrula.',
          style: SwanType.bodySm(palette.inkMuted)),
    ]),
  );

  // --- Locker Delivery Strip ---


  // --- Category Filter Pills ---
  Widget _buildCategoryPills(SwanPalette palette) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterPill(
            palette,
            label: 'Tümü',
            isSelected: _filter.condition == null && _filter.delivery == null,
            onTap: () => setState(() => _filter = const MarketFilter()),
          ),
          _filterPill(
            palette,
            label: 'Sıfır Ürünler',
            isSelected: _filter.condition == ItemCondition.isNew,
            onTap: () => setState(() => _filter = _filter.copyWith(
                  condition: _filter.condition == ItemCondition.isNew
                      ? null
                      : ItemCondition.isNew,
                )),
          ),
          _filterPill(
            palette,
            label: 'Onaylı İkinci El',
            isSelected: _filter.sellerType == 'individual',
            onTap: () => setState(() => _filter = _filter.copyWith(
                  sellerType: _filter.sellerType == 'individual'
                      ? null
                      : 'individual',
                )),
          ),
          _filterPill(
            palette,
            label: 'Resmi Mağaza',
            isSelected: _filter.sellerType == 'verified_store',
            onTap: () => setState(() => _filter = _filter.copyWith(
                  sellerType: _filter.sellerType == 'verified_store'
                      ? null
                      : 'verified_store',
                )),
          ),
          _filterPill(
            palette,
            label: 'Kargo',
            icon: Icons.local_shipping_outlined,
            isSelected: _filter.delivery == DeliveryKind.shipping,
            onTap: () => setState(() => _filter = _filter.copyWith(
                  delivery: _filter.delivery == DeliveryKind.shipping
                      ? null
                      : DeliveryKind.shipping,
                )),
          ),
          _filterPill(
            palette,
            label: 'Fiyata Göre',
            icon: Icons.sort_rounded,
            isSelected: _filter.sort == 'price_asc',
            onTap: () => setState(() => _filter = _filter.copyWith(
                  sort: _filter.sort == 'price_asc' ? 'new' : 'price_asc',
                )),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(
    SwanPalette palette, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? context.swan.accentFill : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? context.swan.accentFill : palette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14, color: isSelected ? context.swan.onAccent : palette.inkMuted),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(
              label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(
                isSelected ? context.swan.onAccent : palette.inkMuted,
                w: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            )),
          ],
        ),
      ),
    );
  }

  // --- Products Header ---
  Widget _buildProductsHeader(SwanPalette palette) => Text(
    _storeSection == 0 ? 'Mağaza & Bireysel İlanlar' : 'İkinci El Ekipmanlar',
    maxLines: 1, overflow: TextOverflow.ellipsis,
    style: SwanType.h3(palette.ink),
  );

  // --- Product Card ---
  Widget _buildProductCard(
    BuildContext context,
    SwanPalette palette,
    bool isDark,
    MarketItem it,
    bool isFav,
  ) {
    return GestureDetector(
      onTap: () =>
          Navigator.pushNamed(context, '/urun', arguments: {'id': it.id}),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.line),
          boxShadow: [
            BoxShadow(
              color: palette.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (it.imagePath != null)
                    Image.network(
                      ref.read(marketplaceServiceProvider).imageUrl(it.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _noImage(palette),
                    )
                  else
                    _noImage(palette),

                  // Rating or category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    right: SwanSpace.xl * 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(it.isStore ? Icons.storefront_outlined : Icons.person_outline_rounded,
                              size: 11, color: context.swan.accent),
                          const SizedBox(width: 3),
                          Flexible(child: Text(
                            it.isStore ? 'Mağaza' : 'Bireysel',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.caption(palette.ink,
                                w: FontWeight.w700),
                          )),
                        ],
                      ),
                    ),
                  ),

                  // Status overlay if not active
                  if (it.status != MarketStatus.active)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        color: palette.surface.withValues(alpha: .96),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        child: Text(
                          it.status.label,
                          style: SwanType.caption(palette.ink,
                              w: FontWeight.w800),
                        ),
                      ),
                    ),

                  // Favorite button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        await ref.read(marketplaceServiceProvider).setFavorite(it.id, !isFav);
                        ref.invalidate(marketFavoritesProvider);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.surface.withValues(alpha: .96),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 14,
                          color: isFav ? palette.danger : palette.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(
                        it.price == null ? 'Fiyat yok' : money(it.price!), maxLines: 1, overflow: TextOverflow.ellipsis, style: SwanType.bodySm(context.swan.accent, w: FontWeight.w800),
                      )),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.swan.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 14, color: context.swan.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    it.isStore
                        ? (it.storeName ?? 'Resmi Kulüp')
                        : (it.condition?.label ?? 'İkinci el'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.caption(palette.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noImage(SwanPalette palette) => Container(
        color: palette.surfaceAlt,
        alignment: Alignment.center,
        child: Icon(Icons.sports_rounded, size: 28, color: palette.inkMuted),
      );

  Widget _buildEmpty(BuildContext context, SwanPalette palette) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          children: [
            Icon(Icons.storefront_rounded, size: 40, color: palette.inkMuted),
            const SizedBox(height: 10),
            Text('Henüz listelenmiş ürün yok',
                style: SwanType.bodySm(palette.ink, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Aramayı veya filtreleri değiştirip tekrar deneyebilirsin.',
                style: SwanType.caption(palette.inkMuted)),
          ],
        ),
      );
}
