import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Kulüp Sepeti ve Güvenli Ödeme ekranı.
///
/// Stitch `kul_p_sepeti_ve_g_venli_deme` tasarımı:
/// - Sipariş özeti ve ürün adedi kontrolü
/// - Teslimat yöntemi seçimi (Poligonda dolaba teslimat / Eve kargo)
/// - Sepetteki lisanslı ürünler, miktar artırma/azaltma ve silme
/// - Kupon kodu (SWAN-ELIT-2025) ve SwanPuan sadakat indirimi
/// - Kayıtlı kredi kartı, kulüp bakiyesi ve havale/FAST ödeme yöntemleri
/// - 256-bit SSL güvenceli anında sipariş onaylama modalı
class CartCheckoutScreen extends ConsumerStatefulWidget {
  const CartCheckoutScreen({super.key});

  @override
  ConsumerState<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends ConsumerState<CartCheckoutScreen> {
  int _fulfillmentMethod = 0; // 0: Dolap (Ücretsiz), 1: Kargo (₺65)
  int _paymentMethod = 0; // 0: Garanti BBVA, 1: Kulüp Bakiyesi, 2: FAST
  bool _useSwanPoints = true;
  bool _hasCoupon = true;

  int _jerseyQty = 1;
  int _vanesQty = 1;
  bool _hasSlotBooking = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final subtotal = (_jerseyQty * 680) + (_vanesQty * 340) + (_hasSlotBooking ? 250 : 0);
    final discount = _hasCoupon ? 100 : 0;
    final pointsDiscount = _useSwanPoints ? 45 : 0;
    final shippingFee = _fulfillmentMethod == 1 ? 65 : 0;
    final total = subtotal - discount - pointsDiscount + shippingFee;

    final itemCount = (_jerseyQty > 0 ? 1 : 0) +
        (_vanesQty > 0 ? 1 : 0) +
        (_hasSlotBooking ? 1 : 0);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 132),
              children: [
                _buildTopBar(context, ink, surf, line),
                const SizedBox(height: 14),
                _buildHeader(itemCount),
                const SizedBox(height: 16),
                _buildFulfillmentSelector(isDark, surf, line, ink),
                const SizedBox(height: 18),
                _buildCartItemsSection(isDark, surf, line, ink),
                const SizedBox(height: 18),
                _buildCouponAndPointsSection(isDark, surf, line, ink),
                const SizedBox(height: 18),
                _buildPaymentMethodSection(isDark, surf, line, ink),
                const SizedBox(height: 18),
                _buildOrderBreakdown(
                  surf,
                  line,
                  ink,
                  subtotal,
                  discount,
                  pointsDiscount,
                  shippingFee,
                  total,
                ),
                const SizedBox(height: 20),
                _buildCheckoutButton(context, total),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    Color ink,
    Color surf,
    Color line,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SwanSport Mağaza',
                  style: SwanType.caption(kTeal, w: FontWeight.w700),
                ),
                Text('Sepet & Ödeme', style: SwanType.h2(ink)),
              ],
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.notifications_none_rounded, color: ink),
              onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: kTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text('Sipariş Özeti', style: SwanType.h1(SwanColors.textPrimary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$itemCount Ürün',
                style: SwanType.caption(kTeal, w: FontWeight.w700),
              ),
            ),
          ],
        ),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _jerseyQty = 0;
              _vanesQty = 0;
              _hasSlotBooking = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sepet temizlendi.'),
                backgroundColor: SwanColors.textSecondary,
              ),
            );
          },
          icon: const Icon(
            Icons.delete_sweep_rounded,
            size: 16,
            color: Color(0xFFBA1A1A),
          ),
          label: const Text(
            'Sepeti Temizle',
            style: TextStyle(
              color: Color(0xFFBA1A1A),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFulfillmentSelector(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Teslimat & Hizmet Yöntemi',
              style: SwanType.bodySm(ink, w: FontWeight.w700),
            ),
            Row(
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: kTeal),
                const SizedBox(width: 4),
                Text(
                  'Kulüp Doğrulamalı',
                  style: SwanType.caption(kTeal, w: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Option 1: Locker
        GestureDetector(
          onTap: () => setState(() => _fulfillmentMethod = 0),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _fulfillmentMethod == 0 ? kTeal : line,
                width: _fulfillmentMethod == 0 ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    size: 18,
                    color: kTeal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Poligonda Dolaba Teslimat',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Ücretsiz',
                              style: SwanType.caption(
                                kTeal,
                                w: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Bugün En Geç 16:30',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? SwanPalette.dark.surfaceAlt
                              : const Color(0xFFF1F4F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Maslak Kampüsü, Zeynep Yılmaz Adına 14 No\'lu Sporcu Dolabı',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _fulfillmentMethod == 0
                        ? kTeal
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _fulfillmentMethod == 0 ? kTeal : line,
                    ),
                  ),
                  child: _fulfillmentMethod == 0
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Option 2: Courier
        GestureDetector(
          onTap: () => setState(() => _fulfillmentMethod = 1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _fulfillmentMethod == 1 ? kTeal : line,
                width: _fulfillmentMethod == 1 ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF575E70).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: Color(0xFF575E70),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Eve Kargo',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Yurtiçi Kargo',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                        ],
                      ),
                      Text(
                        '2 İş Gününde Kapında',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₺65',
                  style: SwanType.bodySm(ink, w: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _fulfillmentMethod == 1
                        ? kTeal
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _fulfillmentMethod == 1 ? kTeal : line,
                    ),
                  ),
                  child: _fulfillmentMethod == 1
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemsSection(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sepetteki Ürünler',
              style: SwanType.bodySm(ink, w: FontWeight.w700),
            ),
            Text(
              'Lisanslı Sipariş',
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Item 1: Jersey
        if (_jerseyQty > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        size: 28,
                        color: kTeal,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marmara SK 2025 Dry-Fit Forma',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            'Beden: M • İsim: Z. YILMAZ #104',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kTeal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Kulüp İndirimi',
                              style: SwanType.caption(kTeal, w: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFBA1A1A),
                      ),
                      onPressed: () => setState(() => _jerseyQty = 0),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQtyStepper(
                      _jerseyQty,
                      (q) => setState(() => _jerseyQty = q),
                      isDark,
                    ),
                    Text(
                      '₺${_jerseyQty * 680}',
                      style: SwanType.h3(ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Item 2: SpinWing
        if (_vanesQty > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6ED6DF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.air_rounded,
                        size: 28,
                        color: Color(0xFF00666D),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SpinWing Kanat (50\'li Paket)',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            'Renk: Turkuaz Metalik • 1 3/4"',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFBA1A1A),
                      ),
                      onPressed: () => setState(() => _vanesQty = 0),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQtyStepper(
                      _vanesQty,
                      (q) => setState(() => _vanesQty = q),
                      isDark,
                    ),
                    Text(
                      '₺${_vanesQty * 340}',
                      style: SwanType.h3(ink),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Item 3: Slot Reservation
        if (_hasSlotBooking)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00818A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.sports_score_rounded,
                        size: 28,
                        color: Color(0xFF00818A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Açık Saha 70m Hat 3A Poligon',
                            style: SwanType.bodySm(ink, w: FontWeight.w700),
                          ),
                          Text(
                            '15 Nisan • 14:00 - 15:30',
                            style: SwanType.caption(SwanColors.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dürbün & Sehpa Ekstralı',
                            style: SwanType.caption(kTeal, w: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFBA1A1A),
                      ),
                      onPressed: () => setState(() => _hasSlotBooking = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? SwanPalette.dark.surfaceAlt
                            : const Color(0xFFF1F4F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '90 Dk Rezervasyon',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ),
                    Text('₺250', style: SwanType.h3(ink)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildQtyStepper(int qty, ValueChanged<int> onChanged, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? SwanPalette.dark.surfaceAlt : const Color(0xFFF1F4F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 16),
            onPressed: () {
              if (qty > 1) onChanged(qty - 1);
            },
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Text(
            '$qty',
            style: SwanType.bodySm(
              SwanColors.textPrimary,
              w: FontWeight.w700,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 16),
            onPressed: () => onChanged(qty + 1),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildCouponAndPointsSection(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Column(
      children: [
        // Kupon Kartı
        if (_hasCoupon)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kTeal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.sell_rounded, size: 18, color: kTeal),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'SWAN-ELIT-2025',
                              style: SwanType.bodySm(ink, w: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: kTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Uygulandı',
                                style: SwanType.caption(
                                  kTeal,
                                  w: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Kulüp Başarı İndirimi (-₺100)',
                          style: SwanType.caption(SwanColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _hasCoupon = false),
                  child: Text(
                    'Kaldır',
                    style: SwanType.caption(SwanColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        // SwanPuan Kartı
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stars_rounded,
                      size: 20,
                      color: Color(0xFFEAB308),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SwanPuan Kullan',
                        style: SwanType.bodySm(ink, w: FontWeight.w700),
                      ),
                      Text(
                        '450 puan hazır (-₺45 indirim)',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              Switch.adaptive(
                value: _useSwanPoints,
                onChanged: (v) => setState(() => _useSwanPoints = v),
                activeThumbColor: kTeal,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(
    bool isDark,
    Color surf,
    Color line,
    Color ink,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ödeme Yöntemi',
          style: SwanType.bodySm(ink, w: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        // Kart 1: Kayıtlı Kredi Kartı
        _buildPaymentOption(
          0,
          Icons.credit_card_rounded,
          'Garanti BBVA Bonus',
          '•••• 4021 • Zeynep Yılmaz',
          surf,
          line,
          ink,
        ),
        const SizedBox(height: 10),
        // Kart 2: Kulüp Bakiyesi
        _buildPaymentOption(
          1,
          Icons.account_balance_wallet_rounded,
          'Kulüp Bakiyesi',
          'Mevcut Bakiye: ₺2.400',
          surf,
          line,
          ink,
        ),
        const SizedBox(height: 10),
        // Kart 3: Havale / FAST
        _buildPaymentOption(
          2,
          Icons.receipt_long_rounded,
          'Banka Havalesi / FAST',
          'Dekont ile Doğrulama',
          surf,
          line,
          ink,
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    int index,
    IconData icon,
    String title,
    String subtitle,
    Color surf,
    Color line,
    Color ink,
  ) {
    final isSelected = _paymentMethod == index;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = index),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? kTeal : line,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? kTeal.withValues(alpha: 0.12)
                        : const Color(0xFFF1F4F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: isSelected ? kTeal : ink),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                    Text(
                      subtitle,
                      style: SwanType.caption(SwanColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isSelected ? kTeal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? kTeal : line),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderBreakdown(
    Color surf,
    Color line,
    Color ink,
    int subtotal,
    int discount,
    int pointsDiscount,
    int shippingFee,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hesap Detayı', style: SwanType.bodySm(ink, w: FontWeight.w700)),
          const SizedBox(height: 12),
          _buildBillRow('Ara Toplam', '₺$subtotal', false, ink),
          const SizedBox(height: 6),
          if (discount > 0) ...[
            _buildBillRow('Lisanslı Sporcu İndirimi', '-₺$discount', true, ink),
            const SizedBox(height: 6),
          ],
          if (pointsDiscount > 0) ...[
            _buildBillRow('SwanPuan İndirimi', '-₺$pointsDiscount', true, ink),
            const SizedBox(height: 6),
          ],
          _buildBillRow(
            'Teslimat',
            shippingFee == 0 ? 'Ücretsiz' : '₺$shippingFee',
            false,
            ink,
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Toplam Tutar', style: SwanType.h2(ink)),
              Text('₺$total', style: SwanType.h1(kTeal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value,
    bool isDiscount,
    Color ink,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: SwanType.caption(SwanColors.textSecondary)),
        Text(
          value,
          style: SwanType.caption(
            isDiscount ? kTeal : ink,
            w: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton(BuildContext context, int total) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => _showSuccessCheckoutModal(context, total),
            icon: const Icon(Icons.lock_rounded, size: 18),
            label: Text('₺$total • Siparişi Onayla & Güvenli Öde'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              textStyle: SwanType.body(Colors.white, w: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              size: 14,
              color: SwanColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '256-bit SSL ve Kulüp Mali Denetim Güvencesi',
              style: SwanType.caption(SwanColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  void _showSuccessCheckoutModal(BuildContext context, int total) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: kTeal,
                size: 36,
              ),
            ),
            const SizedBox(height: 14),
            Text('Sipariş Onaylandı!', style: SwanType.h1(SwanColors.textPrimary)),
            const SizedBox(height: 4),
            Text(
              '₺$total tutarındaki ödemeniz güvenli şekilde alındı.',
              style: SwanType.bodySm(SwanColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sipariş Kodu',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                      Text(
                        '#SWAN-2025-9481',
                        style: SwanType.caption(kTeal, w: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Teslimat Dolabı',
                        style: SwanType.caption(SwanColors.textSecondary),
                      ),
                      Text(
                        '14 No\'lu Dolap (PIN: 8492)',
                        style: SwanType.caption(
                          SwanColors.textPrimary,
                          w: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/dashboard',
                    (_) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Ana Sayfaya Dön',
                  style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
