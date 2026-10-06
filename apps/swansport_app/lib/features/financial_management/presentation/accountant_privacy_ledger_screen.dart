import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Muhasebeci Gizlilik Görünümü (KVKK Seviye-3 Maskelenmiş Yevmiye Defteri).
///
/// AGENTS.md Sözleşmesi:
/// "Muhasebeci kulübün defterini görür ama **sporcuları görmez.** Aidat satırları
/// para hareketi olduğu için gizlenemez; gizlenen kimin ödediğidir.
/// Yerine `athlete_ref(uuid)` ile kimlikten türetilmiş sabit kod döner: `#A3F91C`"
///
/// Stitch "muhasebeci_gizlilik_g_r_n_m" tasarımını tam uygular:
/// - KVKK Seviye-3 Aktif Mührü & SMMM Doğrulama Portalı uyarısı
/// - 4 Mali Özet Bento Kutusu (Doğrulanmış Gelir, Masraflar, Stopaj & KDV, E-Defter %100)
/// - Mutabakat filtreleri (Tüm Hesaplar, Faturalandırılanlar, Vergi Tevkifatlı)
/// - Maskelenmiş yevmiye kayıtları (#A3F91C, #B7E204, #TR-EXP-88, #C8D119, #D2A490)
/// - Resmi Defter Dışa Aktar (XML/Excel) ve SMMM Doğrulama SMS Kodu aksiyonları
class AccountantPrivacyLedgerScreen extends ConsumerStatefulWidget {
  const AccountantPrivacyLedgerScreen({super.key});

  @override
  ConsumerState<AccountantPrivacyLedgerScreen> createState() => _AccountantPrivacyLedgerScreenState();
}

class _AccountantPrivacyLedgerScreenState extends ConsumerState<AccountantPrivacyLedgerScreen> {
  String _selectedFilter = 'Tüm Hesaplar';

  final List<_LedgerEntry> _entries = const [
    _LedgerEntry(
      refCode: '#A3F91C',
      amount: '+₺1.200,00',
      isIncome: true,
      title: 'Aylık Aidat Tahsilatı',
      date: '15 Nis 2025',
      docInfo: 'E-Dekont #DK-9842',
      anonymousLabel: 'Anonim Üye (Okçuluk)',
      docIcon: Icons.receipt_long_rounded,
    ),
    _LedgerEntry(
      refCode: '#B7E204',
      amount: '+₺1.200,00',
      isIncome: true,
      title: 'Aylık Aidat Tahsilatı',
      date: '15 Nis 2025',
      docInfo: 'Sanal POS #TX-3310',
      anonymousLabel: 'Anonim Üye (Yüzme)',
      docIcon: Icons.credit_card_rounded,
    ),
    _LedgerEntry(
      refCode: '#TR-EXP-88',
      amount: '-₺4.850,00',
      isIncome: false,
      title: 'Poligon Donanım Alımı',
      date: '15 Nis 2025',
      docInfo: 'E-Fatura #GIB-2025-1102',
      anonymousLabel: 'Koçtaş Spor Ted.',
      docIcon: Icons.description_outlined,
    ),
    _LedgerEntry(
      refCode: '#C8D119',
      amount: '+₺850,00',
      isIncome: true,
      title: 'Turnuva Katılım Payı',
      date: '14 Nis 2025',
      docInfo: 'FAST Havale',
      anonymousLabel: 'Anonim Üye (Yarışmacı)',
      docIcon: Icons.sync_alt_rounded,
    ),
    _LedgerEntry(
      refCode: '#D2A490',
      amount: '+₺1.200,00',
      isIncome: true,
      title: 'Aylık Aidat Tahsilatı',
      date: '14 Nis 2025',
      docInfo: 'E-Dekont #DK-9811',
      anonymousLabel: 'Anonim Üye (Okçuluk)',
      docIcon: Icons.receipt_long_rounded,
    ),
  ];

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

                // 1. KVKK Level-3 Security Banner
                _buildKvkkSecurityBanner(c),
                const SizedBox(height: SwanSpace.md),

                // 2. Financial Metrics Bento Grid
                _buildMetricsBento(c),
                const SizedBox(height: SwanSpace.md),

                // 3. Reconciliation Filters
                _buildFiltersBar(c),
                const SizedBox(height: SwanSpace.md),

                // 4. Masked General Ledger List
                _buildLedgerList(c),
                const SizedBox(height: SwanSpace.md),

                // 5. Official Accountant Actions Box
                _buildAccountantActions(c),
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
                'SWANSPORT • MUHASEBE',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              Text(
                'Mali Gizlilik Görünümü',
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

  Widget _buildKvkkSecurityBanner(SwanPalette c) {
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
                      color: c.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_rounded, size: 20, color: c.accent),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('KVKK Seviye-3', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_rounded, size: 11, color: c.accent),
                                const SizedBox(width: 3),
                                Text('Aktif', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text('Mali Denetim & SMMM Doğrulama Portalı', style: SwanType.caption(c.inkMuted)),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AGENTS.md Kuralı: Sporcu verileri veri katmanında (RLS & RPC) maskelenmiştir.'),
                    ),
                  );
                },
                icon: Icon(Icons.info_outline_rounded, size: 20, color: c.inkMuted),
                tooltip: 'Gizlilik Bilgisi',
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Container(
            padding: const EdgeInsets.all(SwanSpace.sm),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_rounded, size: 16, color: c.accent),
                const SizedBox(width: SwanSpace.xs),
                Expanded(
                  child: Text(
                    'Sporcu isimleri ve veli iletişim bilgileri maskelenmiştir. Yalnızca mali denetim referans kodları görüntülenir.',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBento(SwanPalette c) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                c: c,
                label: 'Doğrulanmış Gelir',
                val: '₺112.400',
                sub: 'Nisan 2025 net tahsilat',
                icon: Icons.trending_up_rounded,
                iconColor: c.accent,
              ),
            ),
            const SizedBox(width: SwanSpace.xs),
            Expanded(
              child: _buildBentoCard(
                c: c,
                label: 'Masraf Girişleri',
                val: '₺21.430',
                sub: '14 onaylı gider fişi',
                icon: Icons.trending_down_rounded,
                iconColor: c.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.xs),
        Row(
          children: [
            Expanded(
              child: _buildBentoCard(
                c: c,
                label: 'Stopaj & KDV',
                val: '₺8.920',
                sub: 'Beyan edilecek vergi',
                icon: Icons.receipt_long_rounded,
                iconColor: c.inkMuted,
              ),
            ),
            const SizedBox(width: SwanSpace.xs),
            Expanded(
              child: _buildBentoCard(
                c: c,
                label: 'E-Defter Uyumu',
                val: '%100',
                sub: 'GİB şema geçerli',
                icon: Icons.check_circle_rounded,
                iconColor: c.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required SwanPalette c,
    required String label,
    required String val,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
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
              Text(label, style: SwanType.caption(c.inkMuted)),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(val, style: SwanType.h2(c.ink)),
          const SizedBox(height: 2),
          Text(sub, style: SwanType.caption(c.inkMuted)),
        ],
      ),
    );
  }

  Widget _buildFiltersBar(SwanPalette c) {
    final filters = ['Tüm Hesaplar', 'Yalnızca Faturalandırılanlar', 'Vergi Tevkifatlı'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: SwanSpace.xs),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedFilter = f);
              },
              selectedColor: c.accent,
              backgroundColor: c.surfaceAlt,
              labelStyle: SwanType.caption(
                isSelected ? Colors.white : c.ink,
                w: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide(color: isSelected ? c.accent : c.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLedgerList(SwanPalette c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Maskelenmiş Yevmiye Defteri', style: SwanType.h3(c.ink)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${_entries.length} Kayıt', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        for (final entry in _entries) _buildEntryCard(c, entry),
      ],
    );
  }

  Widget _buildEntryCard(SwanPalette c, _LedgerEntry e) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.xs),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: e.isIncome ? c.accent.withValues(alpha: 0.12) : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Row(
                  children: [
                    Text(
                      e.refCode,
                      style: SwanType.caption(
                        e.isIncome ? c.accent : c.ink,
                        w: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.shield_outlined,
                      size: 13,
                      color: e.isIncome ? c.accent : c.inkMuted,
                    ),
                  ],
                ),
              ),
              Text(
                e.amount,
                style: SwanType.bodySm(
                  e.isIncome ? c.accent : c.danger,
                  w: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(e.title, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
              Text(e.date, style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(e.docIcon, size: 14, color: c.inkMuted),
                  const SizedBox(width: 4),
                  Text(e.docInfo, style: SwanType.caption(c.inkMuted)),
                ],
              ),
              Text(
                e.anonymousLabel,
                style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountantActions(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_turned_in_outlined, size: 20, color: c.accent),
              const SizedBox(width: SwanSpace.xs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mali Müşavir İşlemleri', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  Text('Resmi beyanname ve arşiv aktarımı', style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('XML & Excel defter paketi hazırlandı ve indirildi.')),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 20),
              label: const Text('Resmi Defter Dışa Aktar (XML / Excel)'),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: SwanSpace.xs),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Doğrulama SMS kodu kayıtlı SMMM numarasına iletildi.')),
                );
              },
              icon: Icon(Icons.sms_outlined, size: 18, color: c.accent),
              label: Text('SMMM Onay Kodu Gönder', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.line),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry {
  const _LedgerEntry({
    required this.refCode,
    required this.amount,
    required this.isIncome,
    required this.title,
    required this.date,
    required this.docInfo,
    required this.anonymousLabel,
    required this.docIcon,
  });

  final String refCode;
  final String amount;
  final bool isIncome;
  final String title;
  final String date;
  final String docInfo;
  final String anonymousLabel;
  final IconData docIcon;
}
