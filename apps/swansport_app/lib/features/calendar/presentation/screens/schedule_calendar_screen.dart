import 'package:flutter/material.dart';
import '../../../../app/design/swan_shape.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Takvim & Seans Planı — Calm Athletic Modernism (Stitch Redesign).
/// Supabase `eventsProvider` ve `facilitiesProvider`'a tam bağlı, interaktif haftalık şeritli.
class ScheduleCalendarScreen extends ConsumerStatefulWidget {
  const ScheduleCalendarScreen({super.key});

  static const _kindColor = {
    'training': 0xFF008C95,
    'match': 0xFFFF7A59,
    'meeting': 0xFF3B82F6,
    'other': 0xFF7C5CE6,
  };

  @override
  ConsumerState<ScheduleCalendarScreen> createState() =>
      _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState
    extends ConsumerState<ScheduleCalendarScreen> {
  late DateTime _selectedDate;
  String? _selectedFacilityId; // null = Tümü
  String _selectedKind = 'all'; // all, match, training, meeting, other
  bool _filterBySelectedDay = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      int newMonth = _selectedDate.month + delta;
      int newYear = _selectedDate.year;
      if (newMonth < 1) {
        newMonth = 12;
        newYear -= 1;
      } else if (newMonth > 12) {
        newMonth = 1;
        newYear += 1;
      }
      final daysInMonth = DateTime(newYear, newMonth + 1, 0).day;
      final day =
          _selectedDate.day > daysInMonth ? daysInMonth : _selectedDate.day;
      _selectedDate = DateTime(newYear, newMonth, day);
    });
  }

  DateTime get _weekStart {
    final d = _selectedDate;
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: d.weekday - 1));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    final async = ref.watch(eventsProvider);
    final facilitiesAsync = ref.watch(facilitiesProvider);
    final facilities = facilitiesAsync.valueOrNull ?? const <FacilityRow>[];

    final weekStart = _weekStart;
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekDays = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final now = DateTime.now();
    final isTodaySelected = _isSameDay(_selectedDate, now);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(eventsProvider);
                ref.invalidate(facilitiesProvider);
                await ref.read(eventsProvider.future);
              },
              child: async.when(
                loading: () => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  children: [
                    _buildTopBar(context, palette, club, canManage),
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ),
                error: (e, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  children: [
                    _buildTopBar(context, palette, club, canManage),
                    const SizedBox(height: 24),
                    premiumError(context, '$e'),
                  ],
                ),
                data: (allEvents) {
                  // Filter by facility if selected
                  var filtered = allEvents;
                  if (_selectedFacilityId != null) {
                    filtered = filtered.where((e) {
                      return e.place != null &&
                          e.place!
                              .toLowerCase()
                              .contains(_selectedFacilityId!.toLowerCase());
                    }).toList();
                  }

                  // Filter by kind if selected
                  if (_selectedKind != 'all') {
                    filtered =
                        filtered.where((e) => e.kind == _selectedKind).toList();
                  }

                  // Day events vs all events
                  final dayEvents = filtered
                      .where((e) => _isSameDay(e.startsAt, _selectedDate))
                      .toList()
                    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

                  final displayEvents =
                      _filterBySelectedDay ? dayEvents : filtered;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                    children: [
                      // 1. Stitch Top Bar & Month Selector
                      _buildTopBar(context, palette, club, canManage),
                      const SizedBox(height: 12),

                      // 2. Stitch Category Filter Chips
                      _buildKindFilters(palette, allEvents),
                      const SizedBox(height: 14),

                      // 3. Interactive Week Strip Selector
                      _buildWeekStrip(
                          palette, isDark, weekStart, weekEnd, weekDays),
                      const SizedBox(height: 14),

                      // 4. Facility Filter Chips
                      if (facilities.isNotEmpty) ...[
                        _buildFacilityFilters(palette, facilities),
                        const SizedBox(height: 14),
                      ],

                      // 5. Stitch Hero Match Card
                      const SizedBox(height: 18),

                      // 6. Day Header & Sessions List
                      _buildDayHeader(
                        palette,
                        dayEventsCount: dayEvents.length,
                        totalEventsCount: filtered.length,
                        isToday: isTodaySelected,
                      ),
                      const SizedBox(height: 12),
                      if (displayEvents.isEmpty) ...[
                        if (allEvents.isEmpty)
                          premiumEmpty(
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
                          )
                        else
                          _buildEmptyDayCard(palette, isDark, club, canManage),
                      ] else ...[
                        for (final event in displayEvents)
                          _buildEventCard(
                              context, ref, isDark, palette, event, canManage),
                      ],
                      const SizedBox(height: 16),
                      // 7. Daily Summary Banner
                      _buildDailySummary(palette, isDark, displayEvents.length),
                      const SizedBox(height: 20),

                      // 8. Stitch Yaklaşan Kritik Tarihler
                      const SizedBox(height: 20),

                      // 9. Stitch Bottom Quick Actions
                      _buildBottomActions(context, palette, club, canManage),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  // --- Stitch Top App Bar & Month Selector ---
  Widget _buildTopBar(BuildContext context, SwanPalette palette, ClubRef? club,
      bool canManage) {
    final now = _selectedDate;
    final monthStr = _monthName(now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (Navigator.of(context).canPop())
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 38,
                  height: 38,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: palette.ink),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEZON ${now.year}-${now.year + 1}',
                    style: SwanType.caption(palette.accent, w: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Kulüp Takvimi & Program',
                    style: SwanType.h2(palette.ink),
                  ),
                ],
              ),
            ),
            if (club != null && canManage)
              GestureDetector(
                onTap: () => _addEvent(context, ref, club),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kTealBright, kTeal],
                    ),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: kTeal.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Seans Ekle',
                        style:
                            SwanType.caption(Colors.white, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Month Switcher Capsule
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(
              '${_dayName(_selectedDate.weekday)}, ${_selectedDate.day} $monthStr',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: palette.inkMuted,
                    onPressed: () => _changeMonth(-1),
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 15, color: palette.accent),
                      const SizedBox(width: 6),
                      Text(
                        '$monthStr ${now.year}',
                        style:
                            SwanType.caption(palette.ink, w: FontWeight.w700),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: palette.inkMuted,
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Stitch Category Filter Chips ---
  Widget _buildKindFilters(SwanPalette palette, List<EventRow> allEvents) {
    final matchCount = allEvents.where((e) => e.kind == 'match').length;
    final trainingCount = allEvents.where((e) => e.kind == 'training').length;
    final meetingCount = allEvents.where((e) => e.kind == 'meeting').length;
    final otherCount = allEvents.where((e) => e.kind == 'other').length;

    final categories = [
      {
        'key': 'all',
        'label': 'Tümü',
        'count': allEvents.length,
        'color': palette.accent
      },
      {
        'key': 'match',
        'label': 'Resmi Maçlar',
        'count': matchCount,
        'color': const Color(0xFFFF7A59)
      },
      {
        'key': 'training',
        'label': 'Antrenman',
        'count': trainingCount,
        'color': const Color(0xFF2FBFB6)
      },
      {
        'key': 'meeting',
        'label': 'Taktik & Teori',
        'count': meetingCount,
        'color': const Color(0xFFC0C6D9)
      },
      {
        'key': 'other',
        'label': 'Etkinlik',
        'count': otherCount,
        'color': const Color(0xFF7C5CE6)
      },
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final key = cat['key'] as String;
          final label = cat['label'] as String;
          final count = cat['count'] as int;
          final dotColor = cat['color'] as Color;
          final isSelected = _selectedKind == key;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedKind = key;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? palette.accent : palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? palette.accent : palette.line,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (key != 'all') ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: SwanType.caption(
                      isSelected ? Colors.white : palette.ink,
                      w: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: SwanType.caption(
                        isSelected ? Colors.white : palette.inkMuted,
                        w: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Stitch Hero Match Card ---
  Widget _buildBottomActions(BuildContext context, SwanPalette palette,
          ClubRef? club, bool canManage) =>
      club == null || !canManage
          ? const SizedBox.shrink()
          : FilledButton.icon(
              onPressed: () => _addEvent(context, ref, club),
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Yeni etkinlik ekle'));

  Widget _buildWeekStrip(
    SwanPalette palette,
    bool isDark,
    DateTime weekStart,
    DateTime weekEnd,
    List<DateTime> weekDays,
  ) {
    final rangeText =
        '${weekStart.day} ${_monthShort(weekStart.month)} - ${weekEnd.day} ${_monthShort(weekEnd.month)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: "Bu Hafta" + Prev / Next Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BU HAFTA',
                style: SwanType.caption(palette.ink, w: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate =
                                _selectedDate.subtract(const Duration(days: 7));
                          });
                        },
                        child: Icon(Icons.chevron_left_rounded,
                            size: 18, color: palette.inkMuted),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            rangeText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.caption(palette.ink,
                                w: FontWeight.w700),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate =
                                _selectedDate.add(const Duration(days: 7));
                          });
                        },
                        child: Icon(Icons.chevron_right_rounded,
                            size: 18, color: palette.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 7-day pill strip
          Row(
            children: weekDays.map((day) {
              final isSelected = _isSameDay(day, _selectedDate);
              final isToday = _isSameDay(day, DateTime.now());
              final dayShort = _dayShort(day.weekday);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = day;
                      _filterBySelectedDay = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kTeal
                          : (isToday
                              ? kTeal.withValues(alpha: 0.08)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isToday
                                  ? kTeal.withValues(alpha: 0.3)
                                  : Colors.transparent),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: kTeal.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          dayShort,
                          style: SwanType.caption(
                            isSelected
                                ? Colors.white.withValues(alpha: 0.85)
                                : palette.inkMuted,
                            w: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${day.day}',
                          style: SwanType.bodySm(
                            isSelected ? Colors.white : palette.ink,
                            w: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : (isToday ? kTeal : palette.line),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- Facility Filter Chips ---
  Widget _buildFacilityFilters(
      SwanPalette palette, List<FacilityRow> facilities) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _facilityChip(
            palette,
            label: 'Tümü',
            isSelected: _selectedFacilityId == null,
            onTap: () => setState(() => _selectedFacilityId = null),
          ),
          for (final f in facilities)
            _facilityChip(
              palette,
              label: f.name,
              isSelected: _selectedFacilityId == f.name,
              onTap: () => setState(() {
                _selectedFacilityId =
                    _selectedFacilityId == f.name ? null : f.name;
              }),
            ),
        ],
      ),
    );
  }

  Widget _facilityChip(
    SwanPalette palette, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? kTeal : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? kTeal : palette.line,
          ),
        ),
        child: Text(
          label,
          style: SwanType.caption(
            isSelected ? Colors.white : palette.inkMuted,
            w: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // --- Day Header ---
  Widget _buildDayHeader(
    SwanPalette palette, {
    required int dayEventsCount,
    required int totalEventsCount,
    required bool isToday,
  }) {
    final dayTitle =
        '${_dayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthName(_selectedDate.month)}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  dayTitle,
                  style: SwanType.h3(palette.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Bugün',
                    style: SwanType.caption(kTeal, w: FontWeight.w800),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.line),
              ),
              child: Text(
                '($dayEventsCount Seans)',
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() {
                  _filterBySelectedDay = !_filterBySelectedDay;
                });
              },
              child: Icon(
                _filterBySelectedDay
                    ? Icons.filter_alt_outlined
                    : Icons.filter_alt_off_outlined,
                size: 18,
                color: _filterBySelectedDay ? kTeal : palette.inkMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Empty Day Card ---
  Widget _buildEmptyDayCard(
      SwanPalette palette, bool isDark, ClubRef? club, bool canManage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_available_rounded,
                size: 24, color: palette.inkMuted),
          ),
          const SizedBox(height: 12),
          Text(
            'Bu güne ait planlanmış seans yok',
            style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Haftalık programdan başka bir gün seçebilir veya yeni seans ekleyebilirsin.',
            textAlign: TextAlign.center,
            style: SwanType.caption(palette.inkMuted),
          ),
          if (canManage && club != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _addEvent(context, ref, club),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: kTeal),
                    const SizedBox(width: 4),
                    Text(
                      'Bu Güne Seans Ekle',
                      style: SwanType.caption(kTeal, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- Session Timeline Event Card ---
  Widget _buildEventCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    SwanPalette palette,
    EventRow e,
    bool canManage,
  ) {
    final kindBaseColor =
        Color(ScheduleCalendarScreen._kindColor[e.kind] ?? 0xFF008C95);
    final now = DateTime.now();
    final isLive =
        e.endsAt != null && now.isAfter(e.startsAt) && now.isBefore(e.endsAt!);
    final isPast = e.endsAt != null && now.isAfter(e.endsAt!);
    final isAthlete =
        ref.watch(activeClubProvider).valueOrNull?.role == 'athlete';

    return GestureDetector(
      onTap: (canManage && e.kind == 'match')
          ? () => _setResult(context, ref, e)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(
            color: isLive ? kTeal.withValues(alpha: 0.6) : palette.line,
            width: isLive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isLive
                  ? kTeal.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: isLive ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left status stripe
              Container(
                width: 5,
                color: isLive ? kTeal : (isPast ? palette.line : kindBaseColor),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Time & Status Badge Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: isLive ? kTeal : palette.inkMuted,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${_hm(e.startsAt)} - ${e.endsAt != null ? _hm(e.endsAt!) : "…"}',
                                style: SwanType.caption(
                                  isLive ? kTeal : palette.ink,
                                  w: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (isLive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kTeal,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Devam Ediyor',
                                    style: SwanType.caption(Colors.white,
                                        w: FontWeight.w700),
                                  ),
                                ],
                              ),
                            )
                          else if (e.hasResult)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kTeal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                e.scoreLabel,
                                style:
                                    SwanType.caption(kTeal, w: FontWeight.w800),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: kindBaseColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                e.kindLabel,
                                style: SwanType.caption(kindBaseColor,
                                    w: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Session Title & Venue
                      Text(
                        e.title,
                        style: SwanType.bodySm(palette.ink, w: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: palette.inkMuted),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              e.place?.isNotEmpty == true
                                  ? e.place!
                                  : 'Belirtilmedi',
                              style: SwanType.caption(palette.inkMuted,
                                  w: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Footer Row: Organizer / RSVP / Quick Actions
                      Container(
                        padding: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: palette.line)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // RSVP summary or quick action
                            Expanded(
                              child: _rsvpSummary(ref, e, palette),
                            ),
                            if (canManage &&
                                (isLive || _isSameDay(e.startsAt, now))) ...[
                              GestureDetector(
                                onTap: () {
                                  Navigator.pushNamed(context, '/attendance',
                                      arguments: e.id);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: kTeal.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: kTeal.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fact_check_rounded,
                                          size: 14, color: kTeal),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Yoklama Al',
                                        style: SwanType.caption(kTeal,
                                            w: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Athlete RSVP Buttons
                      if (isAthlete) ...[
                        const SizedBox(height: 10),
                        _rsvpActions(context, ref, e),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- RSVP Summary ---
  Widget _rsvpSummary(WidgetRef ref, EventRow event, SwanPalette palette) {
    final summary = ref.watch(eventRsvpSummaryProvider(event.id)).valueOrNull;
    if (summary == null) {
      return Row(
        children: [
          Icon(Icons.groups_rounded, size: 14, color: palette.inkMuted),
          const SizedBox(width: 4),
          Text('Katılım bilgisi',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w600)),
        ],
      );
    }
    return Row(
      children: [
        Icon(Icons.groups_rounded, size: 14, color: kTeal),
        const SizedBox(width: 4),
        Text(
          '${summary.attending} geliyor · ${summary.uncertain} belirsiz',
          style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
        ),
      ],
    );
  }

  // --- Daily Summary Banner ---
  Widget _buildDailySummary(
      SwanPalette palette, bool isDark, int sessionCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kTeal.withValues(alpha: isDark ? 0.15 : 0.08),
            kTeal.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: kTeal.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kTeal,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: kTeal.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.insights_rounded,
                size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GÜNÜN ÖZETİ',
                  style: SwanType.caption(kTeal, w: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'Seçili günde $sessionCount seans planlandı.',
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Athlete RSVP Buttons ---
  Widget _rsvpActions(BuildContext context, WidgetRef ref, EventRow event) {
    final current =
        ref.watch(myEventRsvpProvider(event.id)).valueOrNull?.status;
    return Row(
      children: [
        _rsvpButton(
            context, ref, event, 'attending', 'Katılacağım', kTeal, current),
        const SizedBox(width: 6),
        _rsvpButton(context, ref, event, 'uncertain', 'Belirsiz',
            SwanPalette.light.warning, current),
        const SizedBox(width: 6),
        _rsvpButton(context, ref, event, 'unavailable', 'Katılamam',
            SwanPalette.light.danger, current),
      ],
    );
  }

  Widget _rsvpButton(
    BuildContext context,
    WidgetRef ref,
    EventRow event,
    String status,
    String label,
    Color color,
    String? current,
  ) {
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Katılım durumu kaydedilemedi: $error')),
              );
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? .18 : .08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: selected ? .8 : .3)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SwanType.caption(color, w: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  // --- Result Modal for Matches ---
  Future<void> _setResult(
      BuildContext context, WidgetRef ref, EventRow e) async {
    final opponent = FormField_('Rakip', hint: 'Kadıköy SK', required: false)
      ..controller.text = e.opponent ?? '';
    final home = FormField_('Bizim skor',
        hint: '3', keyboard: TextInputType.number, required: false)
      ..controller.text = e.homeScore?.toString() ?? '';
    final away = FormField_('Rakip skor',
        hint: '1', keyboard: TextInputType.number, required: false)
      ..controller.text = e.awayScore?.toString() ?? '';
    final note = FormField_('Not', hint: 'Kısa değerlendirme', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Maç Sonucu',
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

  // --- Add Event Flow ---
  Future<void> _addEvent(
      BuildContext context, WidgetRef ref, ClubRef club) async {
    final titleCtrl = TextEditingController();
    final placeCtrl = TextEditingController();
    var kind = 'training';
    var day = _selectedDate;
    var startTime = const TimeOfDay(hour: 17, minute: 30);
    var minutes = 90;
    FacilityRow? facility;
    var repeatOn = false;
    var weekdays = <int>{1, 3, 5};
    var until = day.add(const Duration(days: 90));

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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Widget pill(String label, String value, VoidCallback onTap) =>
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                            style: SwanType.caption(SwanColors.textSecondary,
                                w: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(value,
                            style: SwanType.bodySm(ink, w: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              );

          return Container(
            decoration: BoxDecoration(
              color: surf,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Etkinlik Ekle', style: SwanType.h3(ink)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    autofocus: true,
                    style: SwanType.bodySm(ink, w: FontWeight.w700),
                    decoration: InputDecoration(
                      labelText: 'Başlık',
                      labelStyle: SwanType.caption(SwanColors.textSecondary,
                          w: FontWeight.w600),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    children: [
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      pill('TARİH', '${day.day}.${day.month}.${day.year}',
                          () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: day,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 730)),
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
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (facilities.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tesis', style: SwanType.h3(ink)),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
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
                      ],
                    ),
                    if (facility != null && facility!.status != 'Müsait')
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 15, color: SwanPalette.light.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                  'Bu tesis "${facility!.status}" durumda.',
                                  style: SwanType.caption(
                                      SwanPalette.light.warning,
                                      w: FontWeight.w600)),
                            ),
                          ],
                        ),
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
                      labelStyle: SwanType.caption(SwanColors.textSecondary,
                          w: FontWeight.w600),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: isDark
                          ? SwanPalette.dark.surfaceAlt
                          : SwanPalette.light.surfaceAlt,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat_rounded,
                                size: 18,
                                color: repeatOn
                                    ? kTeal
                                    : SwanColors.textSecondary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text('Tekrarla',
                                  style:
                                      SwanType.bodySm(ink, w: FontWeight.w700)),
                            ),
                            Switch(
                              value: repeatOn,
                              activeTrackColor: kTeal,
                              onChanged: (v) => setLocal(() => repeatOn = v),
                            ),
                          ],
                        ),
                        if (repeatOn) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
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
                                    if (!weekdays.remove(d.$1)) {
                                      weekdays.add(d.$1);
                                    }
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
                                    child: Text(
                                      d.$2,
                                      style: SwanType.caption(
                                        weekdays.contains(d.$1)
                                            ? Colors.white
                                            : SwanColors.textSecondary,
                                        w: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: until,
                                firstDate: day,
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 730)),
                              );
                              if (picked != null)
                                setLocal(() => until = picked);
                            },
                            child: Row(
                              children: [
                                Icon(Icons.event_busy_rounded,
                                    size: 15, color: SwanColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Bitiş: ${until.day}.${until.month}.${until.year}',
                                  style: SwanType.caption(kTeal,
                                      w: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, false),
                          child: Container(
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(SwanRadius.md),
                              border: Border.all(color: line),
                            ),
                            child: Text(
                              'Vazgeç',
                              style: SwanType.bodySm(SwanColors.textSecondary,
                                  w: FontWeight.w700),
                            ),
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
                              gradient: const LinearGradient(
                                  colors: [kTealBright, kTeal]),
                              borderRadius:
                                  BorderRadius.circular(SwanRadius.md),
                            ),
                            child: Text(
                              'Ekle',
                              style: SwanType.bodySm(Colors.white,
                                  w: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    final starts = DateTime(
        day.year, day.month, day.day, startTime.hour, startTime.minute);
    final ends = starts.add(Duration(minutes: minutes));

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
        debugPrint('SwanSport: çakışma sorgusu başarısız — $error');
      }
    }

    if (repeatOn) {
      if (weekdays.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('En az bir gün seç'),
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

  // --- Clash Confirmation Modal ---
  Future<bool?> _confirmClash(
      BuildContext context, String facilityName, List<FacilitySlot> clash) {
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
                child: Text('• ${c.title} — ${_hm(c.startsAt)}-${_hm(c.endsAt)}'
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

  // --- Date & Time Formatter Helpers ---
  String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _monthName(int month) => switch (month) {
        1 => 'Ocak',
        2 => 'Şubat',
        3 => 'Mart',
        4 => 'Nisan',
        5 => 'Mayıs',
        6 => 'Haziran',
        7 => 'Temmuz',
        8 => 'Ağustos',
        9 => 'Eylül',
        10 => 'Ekim',
        11 => 'Kasım',
        12 => 'Aralık',
        _ => '',
      };

  String _monthShort(int month) => switch (month) {
        1 => 'Oca',
        2 => 'Şub',
        3 => 'Mar',
        4 => 'Nis',
        5 => 'May',
        6 => 'Haz',
        7 => 'Tem',
        8 => 'Ağu',
        9 => 'Eyl',
        10 => 'Eki',
        11 => 'Kas',
        12 => 'Ara',
        _ => '',
      };

  String _dayName(int weekday) => switch (weekday) {
        1 => 'Pazartesi',
        2 => 'Salı',
        3 => 'Çarşamba',
        4 => 'Perşembe',
        5 => 'Cuma',
        6 => 'Cumartesi',
        7 => 'Pazar',
        _ => '',
      };

  String _dayShort(int weekday) => switch (weekday) {
        1 => 'Pzt',
        2 => 'Sal',
        3 => 'Çar',
        4 => 'Per',
        5 => 'Cum',
        6 => 'Cmt',
        7 => 'Paz',
        _ => '',
      };
}
