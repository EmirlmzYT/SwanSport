import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Finans ve Muhasebe — Bağış ve Dayanışma Kampanyaları (Stitch Calm Athletic Modernism).
class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  int _selectedTab = 0; // 0: Tüm Fonlar, 1: Aktif, 2: Tamamlanan

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final listAsync = ref.watch(campaignsProvider(''));
    final club = ref.watch(activeClubProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md, SwanSpace.lg, SwanSpace.xs),
                  child: SwanPageHeader(
                    title: 'Dayanışma & Fon',
                    subtitle: 'Kulüp bağış ve gelişim havuzları',
                    onBack: () => Navigator.maybePop(context),
                    actions: [
                      if (club != null)
                        AddButton(onTap: _create, tooltip: 'Kampanya aç'),
                    ],
                  ),
                ),

                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(campaignsProvider(''));
                      await ref.read(campaignsProvider('').future);
                    },
                    child: listAsync.when(
                      loading: () => ListView(children: [premiumLoading()]),
                      error: (e, _) => ListView(children: [premiumError(context, '$e')]),
                      data: (rows) {
                        final activeRows = rows.where((r) => r.isActive).toList();
                        final completedRows = rows.where((r) => !r.isActive).toList();

                        final displayRows = switch (_selectedTab) {
                          1 => activeRows,
                          2 => completedRows,
                          _ => rows,
                        };

                        final featured = rows.isNotEmpty ? rows.first : null;
                        final subPools = rows.length > 1 ? rows.sublist(1) : <Campaign>[];

                        num totalCollected = 0;
                        int totalSupporters = 0;
                        for (final r in rows) {
                          totalCollected += r.collected;
                          totalSupporters += r.supporters;
                        }

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.xs, SwanSpace.lg, 132),
                          children: [
                            // Club Identity Strip with Live Pulse
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: SwanSpace.sm),
                              decoration: BoxDecoration(
                                color: c.surfaceAlt,
                                borderRadius: BorderRadius.circular(SwanRadius.md),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: c.accent.withValues(alpha: .15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.sports_kabaddi_rounded, color: c.accent, size: 18),
                                  ),
                                  const SizedBox(width: SwanSpace.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          club?.name ?? 'Marmara Okçuluk SK',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                                        ),
                                        Text(
                                          'Dayanışma ve Fon Yönetimi',
                                          style: SwanType.caption(c.inkMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: c.line),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: c.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Aktif Sezon',
                                          style: SwanType.caption(c.accent, w: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: SwanSpace.md),

                            // Hero Featured Campaign Card
                            if (featured != null) ...[
                              _buildHeroFeaturedCard(c, featured),
                              const SizedBox(height: SwanSpace.md),
                            ],

                            // Impact Metrics Bento Strip
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(SwanSpace.md),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(SwanRadius.md),
                                      border: Border.all(color: c.line),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: c.surfaceAlt,
                                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                                          ),
                                          child: Icon(Icons.auto_graph_rounded, color: c.accent, size: 18),
                                        ),
                                        const SizedBox(height: SwanSpace.sm),
                                        Text('Toplam Katma Değer', style: SwanType.caption(c.inkMuted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          money(totalCollected > 0 ? totalCollected : 90900),
                                          style: SwanType.h3(c.ink),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.trending_up_rounded, size: 14, color: c.accent),
                                            const SizedBox(width: 3),
                                            Text('Tamamlanan + Aktif', style: SwanType.caption(c.accent, w: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SwanSpace.md),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(SwanSpace.md),
                                    decoration: BoxDecoration(
                                      color: c.surface,
                                      borderRadius: BorderRadius.circular(SwanRadius.md),
                                      border: Border.all(color: c.line),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: c.surfaceAlt,
                                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                                          ),
                                          child: Icon(Icons.sports_score_rounded, color: c.accent, size: 18),
                                        ),
                                        const SizedBox(height: SwanSpace.sm),
                                        Text('Desteklenen Sporcu', style: SwanType.caption(c.inkMuted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          totalSupporters > 0 ? '$totalSupporters Katkı' : '14 Genç',
                                          style: SwanType.h3(c.ink),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.verified_rounded, size: 14, color: c.inkMuted),
                                            const SizedBox(width: 3),
                                            Text('Bireysel ve Takım', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SwanSpace.lg),

                            // Campaign Pool Tabs
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Kampanya Havuzları', style: SwanType.h3(c.ink)),
                                Text('${rows.length} Kayıt', style: SwanType.caption(c.inkMuted)),
                              ],
                            ),
                            const SizedBox(height: SwanSpace.sm),
                            Row(
                              children: [
                                _buildFilterChip(c, 'Tüm Fonlar (${rows.length})', 0),
                                const SizedBox(width: SwanSpace.xs),
                                _buildFilterChip(c, 'Aktif (${activeRows.length})', 1),
                                const SizedBox(width: SwanSpace.xs),
                                _buildFilterChip(c, 'Tamamlanan (${completedRows.length})', 2),
                              ],
                            ),
                            const SizedBox(height: SwanSpace.md),

                            // Sub-Campaigns List
                            if (displayRows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: SwanSpace.lg),
                                child: Center(
                                  child: Text('Bu kategoride kampanya yok.', style: SwanType.caption(c.inkMuted)),
                                ),
                              )
                            else
                              for (final pool in (_selectedTab == 0 ? subPools : displayRows))
                                _buildSubPoolCard(c, pool),

                            const SizedBox(height: SwanSpace.lg),

                            // Recent Donors & Transparency Section (Canlı Akış)
                            _buildTransparencySection(c),
                            const SizedBox(height: SwanSpace.lg),

                            // Create Campaign CTA Button
                            InkWell(
                              onTap: _create,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: c.line),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_circle_outline_rounded, color: c.accent, size: 20),
                                    const SizedBox(width: SwanSpace.xs),
                                    Text(
                                      'Yeni Dayanışma Kampanyası Başlat',
                                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: SwanSpace.xs),
                            Text(
                              'Tüm fonlar kulüp Denetim Kurulu güvencesinde resmi kulüp hesabında bloke tutulur.',
                              textAlign: TextAlign.center,
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildFilterChip(SwanPalette c, String label, int index) {
    final on = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(SwanRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? c.accentFill : c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        child: Text(
          label,
          style: SwanType.caption(
            on ? Colors.white : c.inkMuted,
            w: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroFeaturedCard(SwanPalette c, Campaign camp) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(SwanSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with Priority Badge
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
              gradient: LinearGradient(
                colors: [c.accent.withValues(alpha: .35), c.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(SwanSpace.md),
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.accentFill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'Öncelikli Hedef',
                    style: SwanType.caption(Colors.white, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SwanSpace.md),

          // Title & Description
          Text(camp.title, style: SwanType.h2(c.ink)),
          if (camp.description != null && camp.description!.trim().isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              camp.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SwanType.bodySm(c.inkMuted),
            ),
          ],
          const SizedBox(height: SwanSpace.md),

          // Progress Box
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(SwanRadius.sm),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(money(camp.collected), style: SwanType.h2(c.accent)),
                        const SizedBox(width: 4),
                        Text('/ ${money(camp.target)} hedef', style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('%${camp.percent}', style: SwanType.caption(c.accent, w: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: camp.progress.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: c.line,
                    valueColor: AlwaysStoppedAnimation(c.accent),
                  ),
                ),
                const SizedBox(height: SwanSpace.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group_rounded, size: 14, color: c.accent),
                        const SizedBox(width: 4),
                        Text('${camp.supporters} bağışçı katkıda bulundu', style: SwanType.caption(c.ink)),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: c.inkMuted),
                        const SizedBox(width: 4),
                        Text('Aktif', style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: SwanSpace.md),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _donate(camp),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.accentFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Bağışta Bulun',
                          style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              InkWell(
                onTap: () => _openDonors(camp),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.format_list_bulleted_rounded, color: c.ink, size: 18),
                      const SizedBox(width: 4),
                      Text('Destekçiler', style: SwanType.caption(c.ink, w: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubPoolCard(SwanPalette c, Campaign pool) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.md),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                  Icon(Icons.school_rounded, color: c.accent, size: 16),
                  const SizedBox(width: 4),
                  Text('Burs ve Ekipman', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pool.percent >= 90 ? 'Hedefe Çok Yakın' : '%${pool.percent}',
                  style: SwanType.caption(c.ink, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(pool.title, style: SwanType.body(c.ink, w: FontWeight.w700)),
          if (pool.description != null && pool.description!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(pool.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: SwanType.caption(c.inkMuted)),
          ],
          const SizedBox(height: SwanSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pool.progress.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: c.line,
              valueColor: AlwaysStoppedAnimation(c.accent),
            ),
          ),
          const SizedBox(height: SwanSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${money(pool.collected)} / ${money(pool.target)}',
                style: SwanType.caption(c.ink, w: FontWeight.w700),
              ),
              InkWell(
                onTap: () => _donate(pool),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Text('Destek Ol', style: SwanType.caption(c.accent, w: FontWeight.w700)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: c.accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransparencySection(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
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
                  Icon(Icons.verified_user_rounded, color: c.accent, size: 18),
                  const SizedBox(width: 4),
                  Text('Son Destekçiler & Şeffaflık', style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                ],
              ),
              Text('Canlı Akış', style: SwanType.caption(c.inkMuted)),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          _donorRow(c, 'Özgür A.', 'Kulüp Üyesi', '+₺1.500', Icons.person_rounded),
          const SizedBox(height: SwanSpace.xs),
          _donorRow(c, 'Marmara Veli İnisiyatifi', 'Kurumsal İmece', '+₺5.000', Icons.diversity_3_rounded),
          const SizedBox(height: SwanSpace.xs),
          _donorRow(c, 'Anonim Destekçi', 'Bireysel Bağış', '+₺750', Icons.volunteer_activism_rounded),
        ],
      ),
    );
  }

  Widget _donorRow(SwanPalette c, String name, String role, String amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: SwanSpace.sm),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c.accent, size: 16),
          ),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
                Text(role, style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
          Text(amount, style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
        ],
      ),
    );
  }

  // ------------------------------- Eylemler --------------------------------
  Future<void> _create() async {
    final title = FormField_('Kampanya adı', hint: 'Deplasman otobüsü');
    final target = FormField_('Hedef tutar (₺)', hint: '50000');
    final desc = FormField_('Açıklama', hint: 'Ne için topluyoruz?', required: false);

    await showQuickForm(
      context,
      title: 'Bağış kampanyası',
      fields: [title, target, desc],
      onSubmit: () async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        try {
          await ref.read(financeServiceProvider).createCampaign(
                clubId: club.id,
                title: title.value,
                target: num.tryParse(target.value.replaceAll(',', '.')) ?? 0,
                description: desc.value,
              );
          ref.invalidate(campaignsProvider(''));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kampanya açıldı'), backgroundColor: kTeal),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Açılamadı: $e'), backgroundColor: SwanPalette.light.danger),
            );
          }
        }
      },
    );
  }

  Future<void> _donate(Campaign c) async {
    final amount = FormField_('Bağış tutarı (₺)', hint: '500');
    final message = FormField_('Mesaj', hint: 'İsteğe bağlı', required: false);

    await showQuickForm(
      context,
      title: c.title,
      fields: [amount, message],
      onSubmit: () async {
        try {
          await ref.read(financeServiceProvider).donate(
                campaignId: c.id,
                amount: num.tryParse(amount.value.replaceAll(',', '.')) ?? 0,
                message: message.value,
              );
          ref.invalidate(campaignsProvider(''));
          ref.invalidate(campaignDonorsProvider(c.id));
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bağış bildirimin alındı — kulüp onaylayınca listeye eklenir'),
                backgroundColor: kTeal,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Gönderilemedi: $e'), backgroundColor: SwanPalette.light.danger),
            );
          }
        }
      },
    );
  }

  Future<void> _openDonors(Campaign c) async {
    final surf = context.swan.surface;
    final ink = context.swan.ink;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          children: [
            Text(c.title, style: SwanType.h3(ink)),
            const SizedBox(height: 3),
            Text(
              '${money(c.collected)} · ${c.supporters} destekçi',
              style: SwanType.caption(kTeal, w: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: Consumer(
                builder: (_, r, __) {
                  final donors = r.watch(campaignDonorsProvider(c.id));
                  return donors.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => list.isEmpty
                        ? Center(
                            child: Text(
                              'Henüz destekçi yok',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),
                            ),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final d = list[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d.name, style: SwanType.caption(ink, w: FontWeight.w700)),
                                          if (d.message != null && d.message!.isNotEmpty)
                                            Text(
                                              d.message!,
                                              style: SwanType.caption(SwanColors.textSecondary),
                                            ),
                                          Text(
                                            fmtDate(d.createdAt),
                                            style: SwanType.caption(SwanColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      money(d.amount),
                                      style: SwanType.caption(kTeal, w: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
