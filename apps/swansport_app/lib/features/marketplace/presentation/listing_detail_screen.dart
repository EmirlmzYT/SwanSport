import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';

/// Gerçek ilan bilgileri, görseller, favori ve satıcıyla iletişim.
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
    final images =
        ref.watch(marketImagesProvider(widget.listingId)).valueOrNull ??
            const <String>[];
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
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: c.ink),
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
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isFav
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
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
                          Icon(Icons.sports_rounded,
                              size: 48, color: c.accent.withValues(alpha: 0.5)),
                          const SizedBox(height: SwanSpace.xs),
                          Text('Ürün görseli yok',
                              style: SwanType.caption(c.inkMuted)),
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
                        errorBuilder: (_, __, ___) =>
                            Container(color: c.surfaceAlt),
                      ),
                    ),
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
  Widget _body(SwanPalette c, Map<String, dynamic> m,
      Map<String, dynamic>? store, MarketStatus status) {
    final condition = ItemConditionX.fromCode(m['item_condition'] as String?);
    final description = (m['description'] as String?)?.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${m['title'] ?? 'İlan'}', style: SwanType.h2(c.ink)),
      const SizedBox(height: SwanSpace.md),
      Text(m['price'] is num ? money(m['price'] as num) : 'Fiyat belirtilmemiş',
          style: SwanType.h2(c.accent)),
      const SizedBox(height: SwanSpace.sm),
      Text(status.label, style: SwanType.bodySm(c.inkMuted)),
      if (condition != null)
        Text(condition.label, style: SwanType.bodySm(c.inkMuted)),
      if (store != null)
        Text('${store['name'] ?? 'Mağaza'}', style: SwanType.body(c.ink)),
      if (description != null && description.isNotEmpty) ...[
        const SizedBox(height: SwanSpace.lg),
        Text(description, style: SwanType.body(c.ink)),
      ],
      const SizedBox(height: SwanSpace.lg),
      Text(
          'Ürün ve teslimat koşullarını satıcıyla görüşün. SwanSport üzerinden ödeme alınmaz.',
          style: SwanType.bodySm(c.inkMuted)),
    ]);
  }

  // -------------------------------------------------------------- Eylemler
  Widget _actions(SwanPalette c, Map<String, dynamic> m, bool isMine,
          bool isFav, MarketStatus status) =>
      Padding(
        padding: const EdgeInsets.all(SwanSpace.md),
        child: isMine
            ? _ownerActions(c, status)
            : SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: status.isBuyable && m['owner_id'] != null
                      ? () => _openChat(m)
                      : null,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('Satıcıyla görüş'),
                ),
              ),
      );

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
            child: Text(
                status == MarketStatus.reserved ? 'Yayına al' : 'Rezerve et'),
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
            child: Text(
                status == MarketStatus.sold ? 'Satıldı' : 'Satıldı işaretle'),
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
