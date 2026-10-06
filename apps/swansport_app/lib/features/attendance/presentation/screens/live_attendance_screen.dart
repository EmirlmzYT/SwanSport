import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';

/// Canlı Antrenman Yoklaması — Stitch "Calm Athletic Modernism" Canlı Yoklama Ekranı.
class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});

  @override
  ConsumerState<LiveAttendanceScreen> createState() =>
      _LiveAttendanceScreenState();
}

class _LiveAttendanceScreenState extends ConsumerState<LiveAttendanceScreen> {
  final Map<String, String> _marks = {};
  bool _saving = false;
  String _filter = 'all';

  String? _eventId;
  String? _filledFor;

  static const _opts = [
    ('present', 'Var', Color(0xFF55DBD2), Icons.check),
    ('absent', 'Yok', Color(0xFFFFB4AB), Icons.close),
    ('excused', 'İzin', Color(0xFFFFB6A4), Icons.description),
    ('late', 'Geç/Sakat', Color(0xFFC0C6D9), Icons.medical_services),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final today = _todaysEvents(ref);
    if (_eventId == null && today.isNotEmpty) _eventId = today.first.id;

    final async = _eventId == null
        ? ref.watch(clubAthletesProvider)
        : ref.watch(eventRosterProvider(_eventId!));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: async.when(
              loading: () => premiumLoading(),
              error: (e, _) => premiumError(context, '$e'),
              data: (rows) {
                final allAthletes = _names(rows);
                _prefill(rows);

                final presentCount =
                    _marks.values.where((v) => v == 'present').length;
                final absentCount =
                    _marks.values.where((v) => v == 'absent').length;
                final excusedCount =
                    _marks.values.where((v) => v == 'excused').length;
                final lateCount =
                    _marks.values.where((v) => v == 'late').length;
                final total = allAthletes.length;
                final pct =
                    total == 0 ? 0 : ((presentCount / total) * 100).round();

                final filteredAthletes = allAthletes.where((a) {
                  final status = _marks[a.$1];
                  if (_filter == 'var') return status == 'present';
                  if (_filter == 'yok') return status == 'absent';
                  if (_filter == 'izin') return status == 'excused';
                  if (_filter == 'sakat') return status == 'late';
                  return true;
                }).toList();

                final selectedEvent =
                    today.where((e) => e.id == _eventId).firstOrNull;

                return Column(
                  children: [
                    // --- Header ---
                    _buildHeader(context, c, selectedEvent, club),

                    // --- Scrollable Body ---
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                        children: [
                          // 1. Sub-Header Context Bar
                          _buildContextBar(c, selectedEvent, club),
                          const SizedBox(height: 14),

                          // Event Picker if multiple events exist today
                          if (today.isNotEmpty) ...[
                            _eventPicker(c),
                            const SizedBox(height: 12),
                          ],

                          // 2. Real-Time Metrics & Progress Hero Card (Donut + Cluster)
                          _buildProgressHeroCard(
                            c,
                            total: total,
                            present: presentCount,
                            absent: absentCount,
                            other: excusedCount + lateCount,
                            pct: pct,
                          ),
                          const SizedBox(height: 16),

                          // 3. Quick Bulk Action Shortcuts
                          _buildBulkShortcuts(c, allAthletes),
                          const SizedBox(height: 14),

                          // 4. Filter Pills Bar
                          _buildFilterPills(
                            c,
                            total: total,
                            present: presentCount,
                            absent: absentCount,
                            excused: excusedCount,
                            lateC: lateCount,
                          ),
                          const SizedBox(height: 16),

                          // 5. Athlete Cards Roster
                          if (filteredAthletes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Text(
                                  'Bu filtreye uygun sporcu bulunamadı.',
                                  style: SwanType.bodySm(c.inkMuted),
                                ),
                              ),
                            )
                          else
                            ...List.generate(
                              filteredAthletes.length,
                              (i) => _buildAthleteCard(
                                c: c,
                                id: filteredAthletes[i].$1,
                                name: filteredAthletes[i].$2,
                                index: i,
                              ),
                            ),
                        ],
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(club),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_saving) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('Kaydediliyor…',
                              style: SwanType.bodySm(Colors.white, w: FontWeight.w700)),
                        ] else ...[
                          const Icon(Icons.check_circle_outline, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Yoklamayı Kaydet & Tamamla (${_marks.length} Sporcu)',
                            style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeader(
    BuildContext context,
    SwanPalette c,
    EventRow? event,
    ClubRef? club,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back, color: c.ink, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: c.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canlı Antrenman Yoklaması',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.ink,
                    ),
                  ),
                  Text(
                    club?.name ?? 'SwanSport',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_vert, color: c.inkMuted, size: 20),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-HEADER CONTEXT BAR
  // ---------------------------------------------------------------------------
  Widget _buildContextBar(
    SwanPalette c,
    EventRow? event,
    ClubRef? club,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: c.accent.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'CANLI OTURUM',
                  style: SwanType.caption(c.accent, w: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              event?.title ?? 'U18 Genç Takım • Akşam Antrenmanı',
              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('QR Kamera tarayıcısı başlatılıyor...')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.line),
            ),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, size: 18, color: c.accent),
                const SizedBox(width: 6),
                Text(
                  'Hızlı Tara',
                  style: SwanType.caption(c.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // REAL-TIME METRICS & DONUT PROGRESS HERO
  // ---------------------------------------------------------------------------
  Widget _buildProgressHeroCard(
    SwanPalette c, {
    required int total,
    required int present,
    required int absent,
    required int other,
    required int pct,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GENEL KATILIM ORANI',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$present',
                        style: GoogleFonts.sora(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: c.ink,
                        ),
                      ),
                      Text(
                        '/$total',
                        style: GoogleFonts.sora(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: c.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '%$pct',
                          style: SwanType.caption(c.accent, w: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Radial Progress Donut
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: total == 0 ? 0 : present / total,
                      strokeWidth: 6,
                      backgroundColor: c.bg,
                      valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                    ),
                  ),
                  Icon(Icons.sports_soccer, color: c.accent, size: 22),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 4-item cluster
          Row(
            children: [
              Expanded(
                child: _statClusterItem(c, label: 'Toplam', value: '$total', color: c.ink),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statClusterItem(c, label: 'Var', value: '$present', color: c.accent),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statClusterItem(
                  c,
                  label: 'Yok',
                  value: '$absent',
                  color: const Color(0xFFFFB4AB),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _statClusterItem(
                  c,
                  label: 'İzin/Sakat',
                  value: '$other',
                  color: const Color(0xFFFFB6A4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statClusterItem(
    SwanPalette c, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Text(label, style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.sora(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BULK SHORTCUTS
  // ---------------------------------------------------------------------------
  Widget _buildBulkShortcuts(SwanPalette c, List<(String, String)> all) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _actionChip(
            c,
            icon: Icons.done_all,
            iconColor: c.accent,
            label: 'Tümünü Var Say',
            onTap: () {
              setState(() {
                for (final a in all) {
                  _marks[a.$1] = 'present';
                }
              });
            },
          ),
          const SizedBox(width: 8),
          _actionChip(
            c,
            icon: Icons.edit_note,
            iconColor: c.inkMuted,
            label: 'Antrenman Notu Ekle',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Antrenman not defteri açıldı.')),
              );
            },
          ),
          const SizedBox(width: 8),
          _actionChip(
            c,
            icon: Icons.restart_alt,
            iconColor: c.inkMuted,
            label: 'Sıfırla',
            onTap: () {
              setState(() => _marks.clear());
            },
          ),
        ],
      ),
    );
  }

  Widget _actionChip(
    SwanPalette c, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: SwanType.caption(c.ink, w: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER PILLS
  // ---------------------------------------------------------------------------
  Widget _buildFilterPills(
    SwanPalette c, {
    required int total,
    required int present,
    required int absent,
    required int excused,
    required int lateC,
  }) {
    final filters = [
      ('all', 'Tümü ($total)'),
      ('var', 'Var ($present)'),
      ('yok', 'Yok ($absent)'),
      ('izin', 'İzinli ($excused)'),
      ('sakat', 'Sakat ($lateC)'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSel = _filter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _filter = f.$1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? c.accent : c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSel ? c.accent : c.line),
                ),
                child: Text(
                  f.$2,
                  style: SwanType.caption(
                    isSel ? Colors.white : c.inkMuted,
                    w: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ATHLETE CARD
  // ---------------------------------------------------------------------------
  Widget _buildAthleteCard({
    required SwanPalette c,
    required String id,
    required String name,
    required int index,
  }) {
    final status = _marks[id] ?? 'present';
    final initials = _initials(name);
    final jerseyNo = '#${index + 1}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.line),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: c.accent,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            jerseyNo,
                            style: GoogleFonts.sora(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.sora(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                            ),
                          ),
                          if (index == 0) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.verified, size: 15, color: c.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.bg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              index % 3 == 0
                                  ? 'Forvet'
                                  : (index % 3 == 1 ? 'Orta Saha' : 'Defans'),
                              style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• 18:${35 + (index * 2 % 25)} Sahada',
                            style: SwanType.caption(c.inkMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: status == 'present'
                      ? c.accent.withValues(alpha: 0.2)
                      : (status == 'absent'
                          ? const Color(0xFFFFB4AB).withValues(alpha: 0.2)
                          : const Color(0xFFFFB6A4).withValues(alpha: 0.2)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == 'present'
                      ? Icons.check_circle
                      : (status == 'absent' ? Icons.cancel : Icons.info),
                  size: 18,
                  color: status == 'present'
                      ? c.accent
                      : (status == 'absent'
                          ? const Color(0xFFFFB4AB)
                          : const Color(0xFFFFB6A4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Courtside 4-state Toggle Matrix
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: _opts.map((opt) {
                final isSelected = status == opt.$1;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _marks[id] = opt.$1;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? c.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: c.accent.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            opt.$4,
                            size: 14,
                            color: isSelected ? Colors.white : c.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            opt.$2,
                            style: SwanType.caption(
                              isSelected ? Colors.white : c.inkMuted,
                              w: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 12, color: c.accent),
                  const SizedBox(width: 4),
                  Text('Zamanında katıldı', style: SwanType.caption(c.inkMuted)),
                ],
              ),
              Text(
                'Nabız Bandı: Aktif (#${index + 10})',
                style: SwanType.caption(c.accent, w: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final a = parts.first[0];
    final b = parts.length > 1 ? parts.last[0] : '';
    return (a + b).toUpperCase();
  }

  List<EventRow> _todaysEvents(WidgetRef ref) {
    final all = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final now = DateTime.now();
    final list = all
        .where(
          (e) =>
              e.startsAt.year == now.year &&
              e.startsAt.month == now.month &&
              e.startsAt.day == now.day,
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return list;
  }

  List<(String, String)> _names(List<dynamic> rows) => rows
      .map<(String, String)>(
        (r) => r is RosterEntry
            ? (r.athleteId, r.fullName)
            : (r.id as String, '${r.firstName} ${r.lastName}'.trim()),
      )
      .toList();

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

  Widget _eventPicker(SwanPalette c) {
    final events = _todaysEvents(ref);
    if (events.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: events.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = events[i];
          final on = e.id == _eventId;
          final hh = e.startsAt.hour.toString().padLeft(2, '0');
          final mm = e.startsAt.minute.toString().padLeft(2, '0');
          return InkWell(
            onTap: () => setState(() => _eventId = e.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? c.accent : c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: on ? c.accent : c.line),
              ),
              child: Text(
                '$hh:$mm · ${e.title}',
                style: SwanType.caption(
                  on ? Colors.white : c.ink,
                  w: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save(ClubRef club) async {
    setState(() => _saving = true);
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    try {
      await ref.read(clubDataServiceProvider).saveAttendance(
            club.id,
            Map<String, String>.from(_marks),
            eventId: _eventId,
          );
      if (_eventId != null) ref.invalidate(eventRosterProvider(_eventId!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Yoklama sunucuya başarıyla kaydedildi'),
            backgroundColor: c.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
