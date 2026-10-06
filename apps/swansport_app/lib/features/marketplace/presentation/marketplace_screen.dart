import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
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

    return Scaffold(
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
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                children: [
                  // 1. Top Bar with Search & Action
                  _buildTopBar(context, palette),
                  const SizedBox(height: 12),

                  // 2. Search & Filter Bar
                  _buildSearchBar(palette),
                  const SizedBox(height: 12),

                  // 3. Store Mode Segmented Selector
                  _buildSectionTabs(palette),
                  const SizedBox(height: 14),

                  // 4. Featured Banner based on mode
                  if (_storeSection == 0)
                    _buildOfficialHeroBanner(palette, isDark)
                  else
                    _buildCoachGuaranteeBanner(palette, isDark),
                  const SizedBox(height: 14),

                  // 5. Club Delivery Info Strip
                  _buildLockerDeliveryStrip(palette, isDark),
                  const SizedBox(height: 14),

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
  Widget _buildTopBar(BuildContext context, SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop())
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: palette.ink),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kulüp Pazaryeri',
                  style: SwanType.h2(palette.ink),
                ),
                Text(
                  'Resmi Ürünler & Onaylı Ekipman',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/ilan-ver'),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: kTeal.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_box_rounded,
                    size: 17, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  'İlan Ver',
                  style: SwanType.caption(Colors.white, w: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
  Widget _buildSectionTabs(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _storeSection = 0;
                _filter = _filter.copyWith(sellerType: null);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _storeSection == 0 ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _storeSection == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_rounded,
                        size: 15,
                        color: _storeSection == 0 ? kTeal : palette.inkMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Resmi Mağaza',
                      style: SwanType.caption(
                        _storeSection == 0 ? kTeal : palette.inkMuted,
                        w: _storeSection == 0 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _storeSection = 1;
                _filter = _filter.copyWith(sellerType: 'individual');
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _storeSection == 1 ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _storeSection == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.recycling_rounded,
                        size: 15,
                        color: _storeSection == 1 ? kTeal : palette.inkMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Kulüp İçi 2. El',
                      style: SwanType.caption(
                        _storeSection == 1 ? kTeal : palette.inkMuted,
                        w: _storeSection == 1 ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Official Merchandise Hero Banner ---
  Widget _buildOfficialHeroBanner(SwanPalette palette, bool isDark) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF131D2E), const Color(0xFF0C2428)]
              : [const Color(0xFF004F54), const Color(0xFF00757E)],
        ),
        boxShadow: [
          BoxShadow(
            color: kTeal.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -20,
            child: Icon(
              Icons.shield_outlined,
              size: 150,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Yeni Sezon Koleksiyonu',
                            style: SwanType.caption(Colors.white,
                                w: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kTealBright,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Üyelere %20',
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resmi Kulüp Forması ve Rüzgarlık',
                      style: SwanType.h3(Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Müsabaka standartlarında nefes alan dry-fit kumaş.',
                      style: SwanType.caption(
                          Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Coach Guarantee Banner for Used Market ---
  Widget _buildCoachGuaranteeBanner(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kTeal.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kTeal.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Başantrenör Doğrulama Garantisi',
                      style: SwanType.caption(kTeal, w: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                          color: kTeal, shape: BoxShape.circle),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Tüm ikinci el malzemeler tiller dengesi, mikroskobik çatlak ve tork toleransı testinden geçirilerek listelenir.',
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Locker Delivery Strip ---
  Widget _buildLockerDeliveryStrip(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_clock_rounded,
                size: 16, color: kTeal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Kulüp İçi Doğrudan Teslimat',
                        style: SwanType.caption(palette.ink,
                            w: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('ÜCRETSİZ',
                          style:
                              SwanType.caption(kTeal, w: FontWeight.w800)),
                    ),
                  ],
                ),
                Text(
                  'Siparişiniz poligon dolabınıza veya antrenör masasına teslim edilir.',
                  style: SwanType.caption(palette.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
          color: isSelected ? kTeal : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? kTeal : palette.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14, color: isSelected ? Colors.white : palette.inkMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: SwanType.caption(
                isSelected ? Colors.white : palette.inkMuted,
                w: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Products Header ---
  Widget _buildProductsHeader(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _storeSection == 0 ? 'Resmi ve Onaylı Ürünler' : 'İkinci El Ekipmanlar',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w800),
            ),
            Text(
              'Poligon onaylı ve müsabaka standartlarında',
              style: SwanType.caption(palette.inkMuted),
            ),
          ],
        ),
        Text(
          'Tümü',
          style: SwanType.caption(kTeal, w: FontWeight.w700),
        ),
      ],
    );
  }

  // --- Product Card ---
  Widget _buildProductCard(
    BuildContext context,
    SwanPalette palette,
    bool isDark,
    MarketItem it,
    bool isFav,
  ) {
    final svc = ref.read(marketplaceServiceProvider);

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
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
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
                      svc.imageUrl(it.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _noImage(palette),
                    )
                  else
                    _noImage(palette),

                  // Rating or category badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 11, color: kTealBright),
                          const SizedBox(width: 3),
                          Text(
                            it.isStore ? 'Mağaza' : 'Onaylı',
                            style: SwanType.caption(Colors.white,
                                w: FontWeight.w700),
                          ),
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
                        color: Colors.black.withValues(alpha: .65),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        alignment: Alignment.center,
                        child: Text(
                          it.status.label,
                          style: SwanType.caption(Colors.white,
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
                          size: 14,
                          color: isFav ? SwanPalette.light.danger : Colors.white,
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
                      Text(
                        it.price == null ? 'Fiyat yok' : money(it.price!),
                        style: SwanType.bodySm(kTeal, w: FontWeight.w800),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: kTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: kTeal),
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
