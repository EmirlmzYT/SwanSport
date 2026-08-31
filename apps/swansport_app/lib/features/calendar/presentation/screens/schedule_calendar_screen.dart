import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Takvim & Program — Supabase verisine bağlı, premium tasarım (v3).
class ScheduleCalendarScreen extends ConsumerWidget {
  const ScheduleCalendarScreen({super.key});

  static const _kindColor = {
    'training': 0xFF008C95,
    'match': 0xFFFF7A59,
    'meeting': 0xFF3B82F6,
    'other': 0xFF7C5CE6,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final club = ref.watch(activeClubProvider).valueOrNull;
    // Maç sonucunu yalnızca kulüp yetkilisi girebilir.
    final canManage =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    final async = ref.watch(eventsProvider);

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
                ref.invalidate(eventsProvider);
                await ref.read(eventsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Takvim', style: SwanType.h3(ink)),
                            const SizedBox(height: 3),
                            Text('Yaklaşan Etkinlikler',
                                style: SwanType.h2(ink)),
                          ],
                        ),
                      ),
                      if (club != null)
                        GestureDetector(
                          onTap: () => _addEvent(context, ref, club),
                          child: _addBtn(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (events) {
                      if (events.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.calendar_month_rounded,
                          title: 'Henüz etkinlik yok',
                          subtitle: club == null
                              ? 'Önce Kadro’dan bir kulüp oluştur.'
                              : 'İlk antrenman/maçı ekle.',
                          actionLabel: club == null ? null : 'Etkinlik Ekle',
                          onAction: club == null
                              ? null
                              : () => _addEvent(context, ref, club),
                        );
                      }
                      return Column(
                        children: events
                            .map((e) =>
                                _eventCard(context, ref, isDark, e, canManage))
                            .toList(),
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

  /// Mac sonucunu kaydeder (yalnizca kulup yetkilisi).
  Future<void> _setResult(
      BuildContext context, WidgetRef ref, EventRow e) async {
    final opponent =
        FormField_('Rakip', hint: 'Kad\u0131k\u00f6y SK', required: false)
          ..controller.text = e.opponent ?? '';
    final home = FormField_('Bizim skor',
        hint: '3', keyboard: TextInputType.number, required: false)
      ..controller.text = e.homeScore?.toString() ?? '';
    final away = FormField_('Rakip skor',
        hint: '1', keyboard: TextInputType.number, required: false)
      ..controller.text = e.awayScore?.toString() ?? '';
    final note = FormField_('Not',
        hint: 'K\u0131sa de\u011ferlendirme', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Ma\u00e7 Sonucu',
      note: e.title,
      fields: [opponent, home, away, note],
      onSubmit: () => ref.read(clubDataServiceProvider).setEventResult(
            e.id,
            opponent: opponent.value.isEmpty ? null : opponent.value,
            homeScore: int.tryParse(home.value),
            awayScore: int.tryParse(away.value),
            note: note.value.isEmpty ? null : note.value,
          ),
    );
    if (ok == true) ref.invalidate(eventsProvider);
  }

  Widget _eventCard(BuildContext context, WidgetRef ref, bool isDark,
      EventRow e, bool canManage) {
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final color = Color(_kindColor[e.kind] ?? 0xFF008C95);
    final isAthlete =
        ref.watch(activeClubProvider).valueOrNull?.role == 'athlete';
    return GestureDetector(
      onTap: (canManage && e.kind == 'match')
          ? () => _setResult(context, ref, e)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  children: [
                    Text(_hm(e.startsAt),
                        style: SwanType.h3(ink)),
                    Text('${e.startsAt.day}.${e.startsAt.month}',
                        style: SwanType.caption(SwanColors.textSecondary)),
                  ],
                ),
                const SizedBox(width: 14),
                Container(width: 3, height: 40, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 12, color: SwanColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(e.place ?? '—',
                                style: SwanType.caption(SwanColors.textSecondary)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(e.kindLabel,
                      style: SwanType.caption(color, w: FontWeight.w700)),
                ),
                // Skor girilmisse rozet olarak goster
                if (e.hasResult) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(e.scoreLabel,
                        style: SwanType.caption(kTeal, w: FontWeight.w800)),
                  ),
                ],
              ],
            ),
            if (isAthlete) ...[
              const SizedBox(height: 12),
              _rsvpActions(context, ref, e),
            ] else if (canManage) ...[
              const SizedBox(height: 10),
              _rsvpSummary(ref, e),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rsvpActions(BuildContext context, WidgetRef ref, EventRow event) {
    final current =
        ref.watch(myEventRsvpProvider(event.id)).valueOrNull?.status;
    return Row(children: [
      _rsvpButton(
          context, ref, event, 'attending', 'Katılacağım', kTeal, current),
      const SizedBox(width: 7),
      _rsvpButton(context, ref, event, 'uncertain', 'Belirsiz',
          SwanPalette.light.warning, current),
      const SizedBox(width: 7),
      _rsvpButton(context, ref, event, 'unavailable', 'Katılamam',
          SwanPalette.light.danger, current),
    ]);
  }

  Widget _rsvpButton(BuildContext context, WidgetRef ref, EventRow event,
      String status, String label, Color color, String? current) {
    final selected = current == status;
    return Expanded(
        child: GestureDetector(
      onTap: () async {
        try {
          await ref
              .read(clubDataServiceProvider)
              .setEventRsvp(event.id, status);
          ref.invalidate(myEventRsvpProvider(event.id));
          ref.invalidate(eventRsvpSummaryProvider(event.id));
        } catch (error) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Katılım durumu kaydedilemedi: $error')),
            );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: selected ? .18 : .08),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: color.withValues(alpha: selected ? .8 : .3)),
        ),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.caption(color, w: FontWeight.w700)),
      ),
    ));
  }

  Widget _rsvpSummary(WidgetRef ref, EventRow event) {
    final summary = ref.watch(eventRsvpSummaryProvider(event.id)).valueOrNull;
    if (summary == null) return const SizedBox.shrink();
    return Text(
        'Katılım onayı: ${summary.attending} geliyor · '
        '${summary.uncertain} belirsiz · ${summary.unavailable} gelemiyor',
        style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600));
  }

  /// Etkinlik ekleme.
  ///
  /// Tarih/saat artık sabit değil, seçiliyor. Tesis seçilirse aynı salonda
  /// çakışan bir etkinlik varsa uyarı çıkar — engellenmez, çünkü kulüp bilerek
  /// iki grubu aynı salona koyabilir; karar kullanıcıda, bilgi bizde.
  Future<void> _addEvent(
      BuildContext context, WidgetRef ref, ClubRef club) async {
    final titleCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    var kind = 'training';
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    var day = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    var startTime = const TimeOfDay(hour: 17, minute: 30);
    var minutes = 90;
    FacilityRow? facility;
    var repeatOn = false;
    var weekdays = <int>{1, 3, 5}; // Pzt / Çar / Cum
    var until = DateTime.now().add(const Duration(days: 90));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final facilities =
        ref.read(facilitiesProvider).valueOrNull ?? const <FacilityRow>[];

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        Widget pill(String label, String value, VoidCallback onTap) => Expanded(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? SwanPalette.dark.surfaceAlt
                        : SwanPalette.light.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(value, style: SwanType.bodySm(ink, w: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            );

        return Container(
          decoration: BoxDecoration(
            color: surf,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Etkinlik ekle', style: SwanType.h3(ink)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: SwanType.bodySm(ink, w: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: 'Başlık',
                  labelStyle:
                      SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final k in const [
                  ('training', 'Antrenman'),
                  ('match', 'Maç'),
                  ('meeting', 'Toplantı'),
                ])
                  ChoiceChip(
                    label: Text(k.$2),
                    selected: kind == k.$1,
                    selectedColor: kTeal.withValues(alpha: 0.2),
                    onSelected: (_) => setLocal(() => kind = k.$1),
                  ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                pill('TARİH', '${day.day}.${day.month}.${day.year}', () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: day,
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setLocal(() => day = picked);
                }),
                pill('SAAT', startTime.format(ctx), () async {
                  final picked = await showTimePicker(
                      context: ctx, initialTime: startTime);
                  if (picked != null) setLocal(() => startTime = picked);
                }),
                pill('SÜRE', '$minutes dk', () {
                  setLocal(() => minutes = switch (minutes) {
                        60 => 90,
                        90 => 120,
                        120 => 45,
                        _ => 60,
                      });
                }),
              ]),
              const SizedBox(height: 14),
              // Tesis seçimi — kayıtlı salonlar; yoksa serbest metin.
              if (facilities.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Tesis', style: SwanType.h3(ink)),
                ),
                const SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(
                    label: const Text('Seçilmedi'),
                    selected: facility == null,
                    selectedColor: kTeal.withValues(alpha: .2),
                    onSelected: (_) => setLocal(() => facility = null),
                  ),
                  for (final f in facilities)
                    ChoiceChip(
                      label: Text(f.name),
                      selected: facility?.id == f.id,
                      selectedColor: kTeal.withValues(alpha: .2),
                      onSelected: (_) => setLocal(() => facility = f),
                    ),
                ]),
                if (facility != null && facility!.status != 'Müsait')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 15, color: SwanPalette.light.warning),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Bu tesis "${facility!.status}" durumda.',
                            style: SwanType.caption(SwanPalette.light.warning, w: FontWeight.w600)),
                      ),
                    ]),
                  ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: placeCtrl,
                style: SwanType.bodySm(ink),
                decoration: InputDecoration(
                  labelText: facilities.isEmpty
                      ? 'Yer (opsiyonel)'
                      : 'Farklı yer (opsiyonel)',
                  hintText: 'Deplasman, rakip saha…',
                  labelStyle:
                      SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),

              // Tekrarlama — haftada üç gün çalışan kulüp 12 kaydı elle
              // girmesin diye.
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: isDark
                      ? SwanPalette.dark.surfaceAlt
                      : SwanPalette.light.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Row(children: [
                    Icon(Icons.repeat_rounded,
                        size: 18,
                        color: repeatOn ? kTeal : SwanColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Tekrarla',
                          style: SwanType.bodySm(ink, w: FontWeight.w700)),
                    ),
                    Switch(
                      value: repeatOn,
                      activeTrackColor: kTeal,
                      onChanged: (v) => setLocal(() => repeatOn = v),
                    ),
                  ]),
                  if (repeatOn) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final d in const [
                        (1, 'Pzt'),
                        (2, 'Sal'),
                        (3, 'Çar'),
                        (4, 'Per'),
                        (5, 'Cum'),
                        (6, 'Cmt'),
                        (7, 'Paz'),
                      ])
                        GestureDetector(
                          onTap: () => setLocal(() {
                            if (!weekdays.remove(d.$1)) weekdays.add(d.$1);
                          }),
                          child: Container(
                            width: 42,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: weekdays.contains(d.$1)
                                  ? kTeal
                                  : (isDark
                                      ? const Color(0xFF131D2E)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: line),
                            ),
                            child: Text(d.$2,
                                style: SwanType.caption(weekdays.contains(d.$1)
                                        ? Colors.white
                                        : SwanColors.textSecondary, w: FontWeight.w800)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: until,
                          firstDate: day,
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
                        );
                        if (picked != null) setLocal(() => until = picked);
                      },
                      child: Row(children: [
                        Icon(Icons.event_busy_rounded,
                            size: 15, color: SwanColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('Bitiş: ${until.day}.${until.month}.${until.year}',
                            style: SwanType.caption(kTeal, w: FontWeight.w700)),
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, false),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: Text('Vazgeç',
                          style: SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx, true),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient:
                            const LinearGradient(colors: [kTealBright, kTeal]),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('Ekle',
                          style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    final starts = DateTime(
        day.year, day.month, day.day, startTime.hour, startTime.minute);
    final ends = starts.add(Duration(minutes: minutes));

    // Çakışma kontrolü — yalnızca tesis seçildiyse anlamlı.
    if (facility != null) {
      try {
        final clash = await ref.read(clubOpsServiceProvider).conflicts(
              facilityId: facility!.id,
              start: starts,
              end: ends,
            );
        if (clash.isNotEmpty && context.mounted) {
          final proceed = await _confirmClash(context, facility!.name, clash);
          if (proceed != true) return;
        }
      } catch (error) {
        // Çakışma sorgusu başarısız olursa kaydı engelleme — uyarı veremiyor
        // olmak, etkinlik eklemeyi durdurmak için yeterli sebep değil.
        debugPrint('SwanSport: çakışma sorgusu başarısız — $error');
      }
    }

    // Tekrarlı seri: çakışma kontrolü tek tek yapılmaz, çünkü onlarca kayıt
    // için onlarca uyarı çıkarmak kullanılabilir değil.
    if (repeatOn) {
      if (weekdays.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('En az bir gün seç'),
              backgroundColor: SwanPalette.light.danger));
        }
        return;
      }
      try {
        final n = await ref.read(clubOpsServiceProvider).createEventSeries(
              clubId: club.id,
              title: titleCtrl.text,
              kind: kind,
              from: day,
              until: until,
              hour: startTime.hour,
              minute: startTime.minute,
              minutes: minutes,
              weekdays: weekdays.toList()..sort(),
              facilityId: facility?.id,
              place: placeCtrl.text,
            );
        ref.invalidate(eventsProvider);
        ref.invalidate(facilityLoadProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$n etkinlik oluşturuldu'),
              backgroundColor: kTeal));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Seri oluşturulamadı: $e'),
              backgroundColor: SwanPalette.light.danger));
        }
      }
      return;
    }

    try {
      await ref.read(clubOpsServiceProvider).createEvent(
            clubId: club.id,
            title: titleCtrl.text,
            kind: kind,
            startsAt: starts,
            endsAt: ends,
            facilityId: facility?.id,
            place: placeCtrl.text,
          );
      ref.invalidate(eventsProvider);
      ref.invalidate(facilityLoadProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Etkinlik eklendi'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Eklenemedi: $e'),
            backgroundColor: SwanPalette.light.danger));
      }
    }
  }

  /// Çakışma uyarısı — hangi etkinlikle çakıştığını gösterir.
  Future<bool?> _confirmClash(
      BuildContext context, String facilityName, List<FacilitySlot> clash) {
    String hm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salon çakışması'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$facilityName aynı saatte zaten kullanılıyor:'),
            const SizedBox(height: 10),
            for (final c in clash)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• ${c.title} — ${hm(c.startsAt)}-${hm(c.endsAt)}'
                    '${c.teamName == null ? '' : ' (${c.teamName})'}'),
              ),
            const SizedBox(height: 6),
            const Text('Yine de eklemek istiyor musun?'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yine de ekle')),
        ],
      ),
    );
  }

  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _addBtn() => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
      );
}
