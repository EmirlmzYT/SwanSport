import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Tesisler — salon ve sahaların haftalık kullanımı.
///
/// Doluluk artık elle girilmiyor: takvimdeki etkinliklerden hesaplanıyor.
/// Elle girilen bir sayıyı kimse güncel tutmuyordu, dolayısıyla yanlış bilgi
/// gösteriyordu. Şimdi salonun programı neyse yük de o.
class FacilityManagementScreen extends ConsumerStatefulWidget {
  const FacilityManagementScreen({super.key});

  @override
  ConsumerState<FacilityManagementScreen> createState() =>
      _FacilityManagementScreenState();
}

class _FacilityManagementScreenState
    extends ConsumerState<FacilityManagementScreen> {
  static const _statuses = ['Müsait', 'Bakımda', 'Kapalı'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(facilityLoadProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(facilityLoadProvider);
                await ref.read(facilityLoadProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KULÜP',
                              style: jakarta(
                                  11, FontWeight.w700, SwanColors.textSecondary,
                                  ls: 1.4)),
                          const SizedBox(height: 3),
                          Text('Tesisler',
                              style: sora(25, FontWeight.w800, ink)),
                        ],
                      ),
                    ),
                    AddButton(onTap: _add, tooltip: 'Tesis ekle'),
                  ]),
                  const SizedBox(height: 6),
                  Text('Doluluk, önümüzdeki 7 günün takviminden hesaplanır.',
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                  const SizedBox(height: 16),
                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => list.isEmpty
                        ? premiumEmpty(
                            context,
                            icon: Icons.stadium_rounded,
                            title: 'Tesis tanımlı değil',
                            subtitle:
                                'Salon ve sahalarını ekle; takvime antrenman '
                                'yazarken tesis seçebilir, çakışmaları '
                                'önleyebilirsin.',
                            actionLabel: 'Tesis ekle',
                            onAction: _add,
                          )
                        : Column(
                            children: [
                              for (final f in list) _card(isDark, ink, f),
                            ],
                          ),
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

  Widget _card(bool isDark, Color ink, FacilityLoad f) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final closed = f.status != 'Müsait';
    // Yoğun salon uyarı rengi alır; yüzde ayrıca yazıyla da veriliyor.
    final color = closed
        ? SwanColors.textSecondary
        : f.loadPercent >= 75
            ? const Color(0xFFD9860B)
            : kTeal;

    return GestureDetector(
      onTap: () => _openSchedule(f),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.stadium_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: jakarta(13.5, FontWeight.w800, ink)),
                    if ((f.kind ?? '').isNotEmpty)
                      Text(f.kind!,
                          style: jakarta(10.5, FontWeight.w500,
                              SwanColors.textSecondary)),
                  ],
                ),
              ),
              if (closed)
                PremiumStatusChip(
                  label: f.status,
                  color: f.status == 'Bakımda'
                      ? const Color(0xFFD9860B)
                      : SwanColors.textSecondary,
                  icon: f.status == 'Bakımda'
                      ? Icons.build_rounded
                      : Icons.block_rounded,
                ),
            ]),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: f.loadPercent / 100,
                minHeight: 7,
                backgroundColor: line,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text(
                  f.isIdle
                      ? 'Bu hafta program yok'
                      : '%${f.loadPercent} · ${f.eventCount} etkinlik · ${f.busyLabel}',
                  style: jakarta(11.5, FontWeight.w700,
                      f.isIdle ? SwanColors.textSecondary : color)),
            ]),
            if (f.nextStartsAt != null) ...[
              const SizedBox(height: 10),
              Divider(color: line, height: 1),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: SwanColors.textSecondary),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                      'Sıradaki: ${f.nextTitle ?? "Etkinlik"} · '
                      '${_when(f.nextStartsAt!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(
                          11, FontWeight.w600, SwanColors.textSecondary)),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: SwanColors.textSecondary),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  String _when(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final hm =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (diff == 0) return 'bugün $hm';
    if (diff == 1) return 'yarın $hm';
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[d.weekday - 1]} $hm';
  }

  // ------------------------------- program ---------------------------------
  Future<void> _openSchedule(FacilityLoad f) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(children: [
          Text(f.name, style: sora(18, FontWeight.w800, ink)),
          const SizedBox(height: 3),
          Text('Önümüzdeki 7 gün',
              style: jakarta(11.5, FontWeight.w600, SwanColors.textSecondary)),
          const SizedBox(height: 14),
          Expanded(
            child: Consumer(builder: (_, r, __) {
              final slots = r.watch(facilityScheduleProvider(f.facilityId));
              return slots.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Text(
                            'Bu salona bu hafta hiç etkinlik yazılmamış.',
                            textAlign: TextAlign.center,
                            style: jakarta(12.5, FontWeight.w600,
                                SwanColors.textSecondary)),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 9),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: line),
                            ),
                            child: Row(children: [
                              Container(
                                width: 4,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: s.kind == 'match'
                                      ? const Color(0xFFF43F5E)
                                      : kTeal,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(s.title,
                                        style: jakarta(
                                            12.5, FontWeight.w700, ink)),
                                    Text(
                                        [
                                          _when(s.startsAt),
                                          if (s.teamName != null) s.teamName!,
                                        ].join(' · '),
                                        style: jakarta(10.5, FontWeight.w500,
                                            SwanColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
              );
            }),
          ),
          Divider(color: line, height: 18),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _changeStatus(f);
                },
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: line),
                  ),
                  child: Text('Durum',
                      style: jakarta(
                          12.5, FontWeight.w800, SwanColors.textSecondary)),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/calendar');
                },
                child: Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kTealBright, kTeal]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text('Takvime git',
                      style: jakarta(12.5, FontWeight.w800, Colors.white)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _remove(f);
            },
            child: Text('Tesisi sil',
                style:
                    jakarta(12, FontWeight.w700, const Color(0xFFF43F5E))),
          ),
        ]),
      ),
    );
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _add() async {
    final name = FormField_('Tesis adı', hint: 'Merkez Salon');
    final kind = FormField_('Tür', hint: 'Kapalı salon', required: false);

    await showQuickForm(
      context,
      title: 'Yeni tesis',
      fields: [name, kind],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref
            .read(clubOpsServiceProvider)
            .addFacility(club.id, name.value, kind: kind.value);
        ref.invalidate(facilityLoadProvider);
      }, 'Tesis eklendi'),
    );
  }

  Future<void> _changeStatus(FacilityLoad f) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${f.name} · durum', style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 10),
          for (final s in _statuses)
            ListTile(
              dense: true,
              leading: Icon(
                  s == f.status
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 19,
                  color: s == f.status ? kTeal : SwanColors.textSecondary),
              title: Text(s, style: jakarta(13, FontWeight.w600, ink)),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ]),
      ),
    );
    if (picked == null || picked == f.status) return;

    await _guard(() async {
      await ref
          .read(clubOpsServiceProvider)
          .updateFacility(f.facilityId, status: picked);
      ref.invalidate(facilityLoadProvider);
    }, 'Durum güncellendi');
  }

  Future<void> _remove(FacilityLoad f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tesisi sil'),
        content: Text('${f.name} silinecek. Bu salona yazılmış etkinlikler '
            'silinmez, yalnızca salon bağlantıları kalkar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await ref.read(clubOpsServiceProvider).removeFacility(f.facilityId);
      ref.invalidate(facilityLoadProvider);
    }, 'Tesis silindi');
  }

  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }
}
