import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';

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
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
                  Text('Bağış', style: sora(22, FontWeight.w800, ink)),
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
      bottomNavigationBar: PremiumBottomNav(
        selectedIndex: -1,
        onSelect: (_) {},
        onAction: () {},
      ),
    );
  }

  Widget _card(bool isDark, Color ink, Campaign c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

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
                        style: jakarta(14, FontWeight.w800, ink)),
                    const SizedBox(height: 2),
                    Text(c.clubName ?? 'Kulüp',
                        style: jakarta(
                            11, FontWeight.w600, SwanColors.textSecondary)),
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
                    color: const Color(0xFFD9860B),
                    icon: Icons.schedule_rounded),
            ]),
            if (c.description != null && c.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(c.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(12, FontWeight.w500, SwanColors.textSecondary)
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
                  style: jakarta(13, FontWeight.w800, kTeal)),
              Text('  /  ${money(c.target)}',
                  style: jakarta(
                      11.5, FontWeight.w600, SwanColors.textSecondary)),
              const Spacer(),
              Text('%${c.percent} · ${c.supporters} destekçi',
                  style: jakarta(
                      11, FontWeight.w600, SwanColors.textSecondary)),
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
                            style: jakarta(12.5, FontWeight.w800,
                                SwanColors.textSecondary)),
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
                              jakarta(12.5, FontWeight.w800, Colors.white)),
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
                backgroundColor: const Color(0xFFF43F5E)));
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
            backgroundColor: const Color(0xFFF43F5E)));
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
                backgroundColor: const Color(0xFFF43F5E)));
          }
        }
      },
    );
  }

  /// Destekçi listesi — kulüp görevlisi buradan bekleyen bağışları onaylar.
  Future<void> _openDonors(Campaign c) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

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
          Text(c.title, style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 3),
          Text('${money(c.collected)} · ${c.supporters} destekçi',
              style: jakarta(11.5, FontWeight.w600, kTeal)),
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
                            style: jakarta(12.5, FontWeight.w600,
                                SwanColors.textSecondary)),
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
                                        style: jakarta(
                                            12.5, FontWeight.w700, ink)),
                                    if (d.message != null &&
                                        d.message!.trim().isNotEmpty)
                                      Text(d.message!,
                                          style: jakarta(11, FontWeight.w500,
                                              SwanColors.textSecondary)),
                                    if (d.isPending)
                                      Text('Onay bekliyor',
                                          style: jakarta(
                                              10, FontWeight.w700,
                                              const Color(0xFFD9860B))),
                                  ],
                                ),
                              ),
                              Text(money(d.amount),
                                  style:
                                      jakarta(13, FontWeight.w800, kTeal)),
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
                                      color: const Color(0xFF10B981),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text('Onayla',
                                        style: jakarta(11, FontWeight.w800,
                                            Colors.white)),
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
