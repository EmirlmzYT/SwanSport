import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';

/// Bağış kampanyaları — herkese açık.
///
/// Kampanya görünür olmadan bağış toplanmıyor; o yüzden liste tüm kulüplere
/// açık ve ilerleme çubuğu öne çıkıyor.
class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final list = ref.watch(campaignsProvider(''));
    final club = ref.watch(activeClubProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: surf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: ink),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text('Bağış', style: SwanType.h2(ink)),
                  const Spacer(),
                  if (club != null) AddButton(onTap: _create, tooltip: 'Kampanya aç'),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(campaignsProvider(''));
                    await ref.read(campaignsProvider('').future);
                  },
                  child: list.when(
                    loading: () => ListView(children: [premiumLoading()]),
                    error: (e, _) =>
                        ListView(children: [premiumError(context, '$e')]),
                    data: (rows) => rows.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.only(top: 40),
                            children: [
                              premiumEmpty(
                                context,
                                icon: Icons.volunteer_activism_rounded,
                                title: 'Kampanya yok',
                                subtitle:
                                    'Kulüpler bağış kampanyası açtığında '
                                    'burada görünür.',
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 4, 20, 132),
                            itemCount: rows.length,
                            itemBuilder: (_, i) =>
                                _card(isDark, ink, rows[i]),
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

  Widget _card(bool isDark, Color ink, Campaign c) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    return GestureDetector(
      onTap: () => _openDonors(c),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(c.clubName ?? 'Kulüp',
                        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                  ],
                ),
              ),
              if (!c.isActive)
                PremiumStatusChip(
                    label: 'Kapandı',
                    color: SwanColors.textSecondary,
                    icon: Icons.lock_rounded)
              else if (c.canManage && c.pendingCount > 0)
                PremiumStatusChip(
                    label: '${c.pendingCount} onay',
                    color: SwanPalette.light.warning,
                    icon: Icons.schedule_rounded),
            ]),
            if (c.description != null && c.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(c.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(SwanColors.textSecondary)
                      .copyWith(height: 1.4)),
            ],
            const SizedBox(height: 14),
            // İlerleme çubuğu — yüzde hem çubukta hem yazıyla, renk tek başına
            // anlam taşımıyor.
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: c.progress,
                minHeight: 8,
                backgroundColor: line,
                valueColor: const AlwaysStoppedAnimation(kTeal),
              ),
            ),
            const SizedBox(height: 9),
            Row(children: [
              Text(money(c.collected),
                  style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
              Text('  /  ${money(c.target)}',
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
              const Spacer(),
              Text('%${c.percent} · ${c.supporters} destekçi',
                  style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
            ]),
            if (c.isActive) ...[
              const SizedBox(height: 13),
              Row(children: [
                if (c.canManage) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _close(c),
                      child: Container(
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: line),
                        ),
                        child: Text('Kapat',
                            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                ],
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => _donate(c),
                    child: Container(
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text('Bağış yap',
                          style:
                              SwanType.caption(Colors.white, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _create() async {
    final title = FormField_('Kampanya adı', hint: 'Deplasman otobüsü');
    final target = FormField_('Hedef tutar (₺)', hint: '50000');
    final desc = FormField_('Açıklama',
        hint: 'Ne için topluyoruz?', required: false);

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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Kampanya açıldı'), backgroundColor: kTeal));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Açılamadı: $e'),
                backgroundColor: SwanPalette.light.danger));
          }
        }
      },
    );
  }

  Future<void> _close(Campaign c) async {
    try {
      await ref.read(financeServiceProvider).closeCampaign(c.id);
      ref.invalidate(campaignsProvider(''));
    } catch (e) {
      // Kampanya kapatmak geri alınabilir ama sessizce başarısız olursa
      // kullanıcı kapandı sanır ve bağış almaya devam eder.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Kampanya kapatılamadı: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Bağış bildirimin alındı — kulüp onaylayınca listeye eklenir'),
                backgroundColor: kTeal));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Gönderilemedi: $e'),
                backgroundColor: SwanPalette.light.danger));
          }
        }
      },
    );
  }

  /// Destekçi listesi — kulüp görevlisi buradan bekleyen bağışları onaylar.
  Future<void> _openDonors(Campaign c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

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
        child: Column(children: [
          Text(c.title, style: SwanType.h3(ink)),
          const SizedBox(height: 3),
          Text('${money(c.collected)} · ${c.supporters} destekçi',
              style: SwanType.caption(kTeal, w: FontWeight.w600)),
          const SizedBox(height: 14),
          Expanded(
            child: Consumer(builder: (_, r, __) {
              final donors = r.watch(campaignDonorsProvider(c.id));
              return donors.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text('Henüz destekçi yok',
                            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final d = list[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name,
                                        style: SwanType.caption(ink, w: FontWeight.w700)),
                                    if (d.message != null &&
                                        d.message!.trim().isNotEmpty)
                                      Text(d.message!,
                                          style: SwanType.caption(SwanColors.textSecondary)),
                                    if (d.isPending)
                                      Text('Onay bekliyor',
                                          style: SwanType.caption(SwanPalette.light.warning, w: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Text(money(d.amount),
                                  style:
                                      SwanType.bodySm(kTeal, w: FontWeight.w800)),
                              if (d.canManage && d.isPending) ...[
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () async {
                                    await ref
                                        .read(financeServiceProvider)
                                        .confirmDonation(d.id, true);
                                    ref.invalidate(
                                        campaignDonorsProvider(c.id));
                                    ref.invalidate(campaignsProvider(''));
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: SwanPalette.light.success,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text('Onayla',
                                        style: SwanType.caption(Colors.white, w: FontWeight.w800)),
                                  ),
                                ),
                              ],
                            ]),
                          );
                        },
                      ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}
