import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Kapanan Dönem Kilidi ve Düzeltici Ters İşlem Ekranı.
///
/// AGENTS.md Sözleşmesi:
/// "Kapanmış dönem tetikleyiciyle kilitli (`block_closed_period`). Düzeltme
/// geçmişe dokunmuyor, bugüne ters kayıt yazıyor."
///
/// Stitch "kapanan_d_nem_ve_ters_i_lem" tasarımını tam uygular:
/// - Mali Mühür Aktif (Dönem #2025-03, Kapanış & Sayman İmzası)
/// - Bekleyen Ters İşlem Kartı (Mükerrer Aidat Çekimi, ₺1.200,00, Kart Sonu •••• 4021)
/// - İnteraktif Reddet / İadeyi Onayla aksiyonları ve onay durum bildirimi
/// - Son Mutabakat & İade Kayıtları listesi
/// - Denetim & Güvenlik prosedür uyarısı
class ClosedPeriodReversalScreen extends ConsumerStatefulWidget {
  const ClosedPeriodReversalScreen({super.key});

  @override
  ConsumerState<ClosedPeriodReversalScreen> createState() => _ClosedPeriodReversalScreenState();
}

class _ClosedPeriodReversalScreenState extends ConsumerState<ClosedPeriodReversalScreen> {
  String? _statusFeedback;
  bool _isApproved = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.md,
                SwanSpace.sm,
                SwanSpace.md,
                110,
              ),
              children: [
                _buildHeader(c),
                const SizedBox(height: SwanSpace.md),

                // 1. Closed Period Seal Banner
                _buildSealBanner(c),
                const SizedBox(height: SwanSpace.md),

                // 2. Pending Reversal Transaction Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Text(
                          'Bekleyen Ters İşlem',
                          style: SwanType.h3(c.ink),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusFeedback != null ? '0 Bekleyen' : '1 Onay Bekliyor',
                        style: SwanType.caption(c.danger, w: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),

                // 3. Reversal Detail Card
                _buildReversalCard(c),
                const SizedBox(height: SwanSpace.md),

                // 4. Recent Settlement & Reversal Audit Log
                _buildSettlementLogSection(c),
                const SizedBox(height: SwanSpace.md),

                // 5. Security & Audit Policy Box
                _buildPolicyNotice(c),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.ink),
          tooltip: 'Geri',
        ),
        const SizedBox(width: SwanSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWANSPORT • FİNANS',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              Text(
                'Dönem Kilidi & Ters İşlem',
                style: SwanType.h2(c.ink),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bildirimler',
          icon: Icon(Icons.notifications_none_rounded, color: c.ink),
          onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
        ),
      ],
    );
  }

  Widget _buildSealBanner(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
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
                      color: c.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_rounded, size: 18, color: c.accent),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            'MALİ MÜHÜR AKTİF',
                            style: SwanType.caption(c.accent, w: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text('Mart 2025 Kapatıldı', style: SwanType.h3(c.ink)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                  border: Border.all(color: c.line),
                ),
                child: Text('Dönem #2025-03', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          Container(
            padding: const EdgeInsets.all(SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kapanış & Mühür Tarihi', style: SwanType.caption(c.inkMuted)),
                      const SizedBox(height: 2),
                      Text('31 Mart 2025 • 23:59', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mali Sayman İmzası', style: SwanType.caption(c.inkMuted)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.draw_rounded, size: 15, color: c.accent),
                          const SizedBox(width: 4),
                          Text('Zeynep B.', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 15, color: c.accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Defteri kebir & mutabakat kayıtları bloklandı. Geçmişe dönük satır silinemez.',
                  style: SwanType.caption(c.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReversalCard(SwanPalette c) {
    return Container(
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
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    child: Icon(Icons.swap_horizontal_circle_outlined, size: 20, color: c.ink),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline_rounded, size: 13, color: c.danger),
                          const SizedBox(width: 3),
                          Text('Mükerrer Tahsilat Tespiti', style: SwanType.caption(c.danger, w: FontWeight.w600)),
                        ],
                      ),
                      Text('Mükerrer Aidat Çekimi', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₺1.200,00', style: SwanType.h2(c.ink)),
                  Text('02 Nisan 2025', style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          Container(
            padding: const EdgeInsets.all(SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ödeme Metodu', style: SwanType.caption(c.inkMuted)),
                    Row(
                      children: [
                        Icon(Icons.credit_card_rounded, size: 14, color: c.ink),
                        const SizedBox(width: 4),
                        Text('Kart Sonu •••• 4021', style: SwanType.caption(c.ink, w: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Banka İade Ref.', style: SwanType.caption(c.inkMuted)),
                    Text('#REV-9024', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: SwanSpace.xs),
                Divider(color: c.line, height: 1),
                const SizedBox(height: SwanSpace.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Talep Açıklaması:\n"Veli otomatik talimat verirken aynı zamanda EFT ile manuel ödeme gerçekleştirdi. Sistem ikinci kaydı mükerrer olarak işaretledi."',
                    style: SwanType.caption(c.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          if (_statusFeedback != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: _isApproved ? c.accent.withValues(alpha: 0.12) : c.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isApproved ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 18,
                    color: _isApproved ? c.accent : c.danger,
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    _statusFeedback!,
                    style: SwanType.bodySm(_isApproved ? c.accent : c.danger, w: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () {
                            setState(() {
                              _statusFeedback = 'Talep reddedildi. Saymanlık kaydı korundu.';
                              _isApproved = false;
                            });
                          },
                    icon: Icon(Icons.close_rounded, size: 18, color: c.ink),
                    label: Text('Reddet', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: c.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SwanSpace.sm),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            setState(() => _isProcessing = true);
                            await Future<void>.delayed(const Duration(milliseconds: 600));
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _isApproved = true;
                                _statusFeedback = 'İade bankaya iletildi & Bugüne ters kayıt yazıldı.';
                              });
                            }
                          },
                    icon: const Icon(Icons.currency_exchange_rounded, size: 18),
                    label: Text(_isProcessing ? 'İşleniyor...' : 'İadeyi Onayla'),
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
        ],
      ),
    );
  }

  Widget _buildSettlementLogSection(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Son Mutabakat & İade Kayıtları', style: SwanType.h3(c.ink)),
            Text('Tüm Günlük', style: SwanType.caption(c.accent, w: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        _buildLogTile(
          c: c,
          icon: Icons.account_balance_outlined,
          title: 'Mart Dönemi Bilanço Kapanışı',
          subtitle: '₺164.200 Kasa Devri Kilitlendi',
          badge: 'Mühürlü',
          badgeColor: c.inkMuted,
        ),
        const SizedBox(height: SwanSpace.xs),
        _buildLogTile(
          c: c,
          icon: Icons.undo_rounded,
          title: 'Tesis Rezervasyon İadesi',
          subtitle: '₺450,00 • 28 Mart 2025',
          badge: 'Tamamlandı',
          badgeColor: c.accent,
        ),
      ],
    );
  }

  Widget _buildLogTile({
    required SwanPalette c,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: c.ink),
              ),
              const SizedBox(width: SwanSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                  Text(subtitle, style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(badge, style: SwanType.caption(badgeColor, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyNotice(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: c.accent),
          const SizedBox(width: SwanSpace.xs),
          Expanded(
            child: Text(
              'Güvenlik Prosedürü: Dönem kilidi yalnızca Genel Kurul ve Denetim Kurulu ortak yetkilendirmesiyle geçici olarak esnetilebilir. Tüm düzeltmeler geçmişi silmeden bugüne ters fiş kaydı ekleyerek gerçekleştirilir.',
              style: SwanType.caption(c.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
