import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Canlı Yoklama — Supabase sporcuları + sunucuya kayıt, premium (v3).
class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  ConsumerState<LiveAttendanceScreen> createState() =>
      _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  // athleteId -> present|absent|excused|late
  final Map<String, String> _marks = {};
  bool _saving = false;

  /// Yoklamanın ait olduğu antrenman.
  ///
  /// **0044 öncesi yoktu** ve her yoklama `event_id = null` yazılıyordu:
  /// hiçbir antrenmana ait değildi, RSVP ile eşleştirilemiyordu ve
  /// `unique (event_id, athlete_id)` kısıtı NULL'lar çakışmadığı için
  /// işlemiyordu — aynı sporcu aynı gün defalarca yazılabiliyordu.
  String? _eventId;

  /// Kadro hangi etkinlik için doldurulmuştu. Etkinlik değişince işaretleri
  /// sıfırlamak için tutuluyor; yoksa önceki antrenmanın işaretleri yeni
  /// antrenmana taşınırdı.
  String? _filledFor;

  static final _opts = [
    ('present', 'Var', SwanPalette.light.success),
    ('absent', 'Yok', SwanPalette.light.danger),
    ('excused', 'Mazeret', Color(0xFFF59E0B)),
    ('late', 'Geç', Color(0xFF3B82F6)),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;

    final club = ref.watch(activeClubProvider).valueOrNull;

    // Bugünün antrenmanları — yoklama bir antrenmana ait olmalı.
    final today = _todaysEvents(ref);
    if (_eventId == null && today.isNotEmpty) _eventId = today.first.id;

    // Etkinlik seçiliyse kadro RSVP ve varsa kayıtlı yoklamayla geliyor.
    // Seçili değilse (bugün antrenman yoksa) eski yol: kulüp kadrosu.
    final async = _eventId == null
        ? ref.watch(clubAthletesProvider)
        : ref.watch(eventRosterProvider(_eventId!));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(context, '$e'),
              data: (rows) {
                final athletes = _names(rows);
                _prefill(rows);

                final present =
                    _marks.values.where((v) => v == 'present').length;
                final total = athletes.length;
                final pct = total == 0 ? 0.0 : present / total;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 20, 12),
                      child: Row(
                        children: [
                          _back(context, surf, line, ink),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Canlı Yoklama', style: SwanType.h3(ink)),
                                Text(club?.name ?? 'Kadro',
                                    style: SwanType.h3(ink)),
                              ],
                            ),
                          ),
                          SwanRing(
                            value: pct,
                            size: 52,
                            stroke: 6,
                            track: isDark
                                ? SwanPalette.dark.surfaceAlt
                                : SwanPalette.light.surfaceAlt,
                            progress: kTeal,
                            center: Text('%${(pct * 100).round()}',
                                style: SwanType.h3(ink)),
                          ),
                        ],
                      ),
                    ),
                    // Yoklama bir antrenmana ait olmalı: seçim burada yapılıyor
                    // ve seçilen antrenmanın RSVP'si işaretleri ön-dolduruyor.
                    _eventPicker(isDark, ink, surf, line),
                    const SizedBox(height: 12),
                    if (athletes.isEmpty)
                      Expanded(
                        child: premiumEmpty(
                          context,
                          icon: Icons.groups_rounded,
                          title: 'Sporcu yok',
                          subtitle: 'Önce Kadro’dan sporcu ekle.',
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          itemCount: athletes.length,
                          itemBuilder: (_, i) => _tile(
                              isDark, athletes[i].$1, athletes[i].$2, i, line),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: (club == null)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: surf,
                  border: Border(top: BorderSide(color: line)),
                ),
                child: GestureDetector(
                  onTap: _saving ? null : () => _save(club),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                            color: kTeal.withValues(alpha: 0.34),
                            blurRadius: 18,
                            offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Text(
                      _saving
                          ? 'Kaydediliyor…'
                          : 'Yoklamayı Kaydet · ${_marks.length}',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Bir sporcu satırı.
  ///
  /// `AthleteRow` yerine `(id, ad)` alıyor: kadro iki kaynaktan gelebiliyor —
  /// etkinlik seçiliyse `RosterEntry` (RSVP'li), değilse kulüp kadrosu.
  Widget _tile(
      bool isDark, String id, String name, int i, Color line) {
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final initials = _initials(name);
    return Container(
      decoration:
          BoxDecoration(border: Border(bottom: BorderSide(color: line))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              GradientAvatar(
                  initials: initials,
                  gradientIndex: i % 4,
                  size: 36,
                  radius: 12),
              const SizedBox(width: 11),
              Expanded(
                  child: Text(name,
                      style: SwanType.bodySm(ink, w: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              for (var j = 0; j < _opts.length; j++) ...[
                if (j > 0) const SizedBox(width: 6),
                _tap(id, _opts[j].$1, _opts[j].$2, _opts[j].$3, isDark),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tap(String id, String value, String label, Color color, bool isDark) {
    final on = _marks[id] == value;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _marks[id] = value),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? color : alt,
            borderRadius: BorderRadius.circular(11),
            boxShadow: on
                ? [
                    BoxShadow(
                        color: color.withValues(alpha: 0.34),
                        blurRadius: 12,
                        offset: const Offset(0, 5))
                  ]
                : null,
          ),
          child: Text(label,
              style: SwanType.caption(on ? Colors.white : SwanColors.textSecondary, w: FontWeight.w700)),
        ),
      ),
    );
  }


  // ------------------------------- yardımcılar -------------------------------

  /// Ad soyaddan baş harfler. `AthleteRow.initials` yerine burada hesaplanıyor,
  /// çünkü kadro artık iki farklı tipten gelebiliyor.
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }

  /// Bugün başlayan etkinlikler, saatine göre.
  List<EventRow> _todaysEvents(WidgetRef ref) {
    final all = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final now = DateTime.now();
    final list = all
        .where((e) =>
            e.startsAt.year == now.year &&
            e.startsAt.month == now.month &&
            e.startsAt.day == now.day)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  /// İki farklı kaynağı tek biçime indiriyor: (id, ad).
  ///
  /// Etkinlik seçiliyse [RosterEntry], değilse kulüp kadrosu geliyor. Ekranın
  /// geri kalanı hangisinden geldiğini bilmek zorunda kalmasın.
  List<(String, String)> _names(List<dynamic> rows) => rows
      .map<(String, String)>((r) => r is RosterEntry
          ? (r.athleteId, r.fullName)
          : (r.id as String, '${r.firstName} ${r.lastName}'.trim()))
      .toList();

  /// İşaretleri ön-doldurur.
  ///
  /// Etkinlik seçiliyse RSVP'den: "katılıyorum" → Var, "gelemem" → Yok.
  /// **Yanıt vermeyen boş bırakılıyor.** Eski ekran herkesi varsayılan `Var`
  /// işaretliyordu; antrenör gelmeyenleri kaldırmayı unuttuğunda katılım
  /// olduğundan yüksek görünüyordu. Bilinmeyeni bilinmeyen bırakmak, yanlış
  /// tahmin etmekten iyi.
  ///
  /// Etkinlik yoksa eski davranış korunuyor — orada hiçbir bilgi yok ve
  /// 18 kişiyi tek tek işaretletmek ekranı kullanılamaz hale getirirdi.
  void _prefill(List<dynamic> rows) {
    if (_filledFor == _eventId && _marks.isNotEmpty) return;
    _filledFor = _eventId;
    _marks.clear();

    for (final r in rows) {
      if (r is RosterEntry) {
        final v = r.suggested;
        if (v != null) _marks[r.athleteId] = v;
      } else {
        _marks[r.id as String] = 'present';
      }
    }
  }

  /// Antrenman seçici — yoklamanın hangi antrenmana ait olduğunu söyler.
  Widget _eventPicker(bool isDark, Color ink, Color surf, Color line) {
    final events = _todaysEvents(ref);
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(
          'Bugün planlı antrenman yok — yoklama antrenmana bağlanmadan '
          'kaydedilecek.',
          style: SwanType.caption(SwanColors.textSecondary),
        ),
      );
    }
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = events[i];
          final on = e.id == _eventId;
          final hh = e.startsAt.hour.toString().padLeft(2, '0');
          final mm = e.startsAt.minute.toString().padLeft(2, '0');
          return GestureDetector(
            onTap: () => setState(() => _eventId = e.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? kTeal : surf,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: on ? kTeal : line),
              ),
              child: Text('$hh:$mm · ${e.title}',
                  style: SwanType.caption(on ? Colors.white : ink,
                      w: FontWeight.w700)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(ClubRef club) async {
    setState(() => _saving = true);
    try {
      await ref.read(clubDataServiceProvider).saveAttendance(
            club.id,
            Map<String, String>.from(_marks),
            eventId: _eventId,
          );
      // Kaydedilen yoklama kadroya yansısın: aynı ekranda tekrar bakınca
      // sunucudaki hâli görünmeli.
      if (_eventId != null) ref.invalidate(eventRosterProvider(_eventId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Yoklama sunucuya kaydedildi'),
              backgroundColor: kTeal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: SwanPalette.light.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _back(BuildContext context, Color surf, Color line, Color ink) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: line),
        ),
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: ink),
      ),
    );
  }
}
