import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Liderlik Tablosu & Ligler (Stitch Calm Athletic Modernism)
///
/// Haftalık, Aylık, Sezonluk lig sıralaması, podyum (Top 3),
/// kullanıcı aktif lig statüsü, haftalık meydan okuma ve genel sıralama.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _selectedPeriod = 0; // 0: Haftalık, 1: Aylık, 2: Sezonluk
  int _selectedDiscipline = 0; // 0: Koşu, 1: Ağırlık & Power, 2: Karma Atletizm

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                _buildHeader(context, palette),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    children: [
                      // Period Segmented Control (Haftalık / Aylık / Sezonluk)
                      _buildPeriodTabs(palette),
                      const SizedBox(height: 10),

                      // Sports Discipline Pills
                      _buildDisciplinePills(palette),
                      const SizedBox(height: 14),

                      // Swan Elit Ligi Hero Banner
                      _buildElitLeagueHero(palette, isDark),
                      const SizedBox(height: 20),

                      // Podiums (Top 3 Athletes)
                      _buildPodiumDeck(palette, isDark),
                      const SizedBox(height: 18),

                      // Sticky / Prominent User Status Card
                      _buildUserStatusCard(palette, isDark),
                      const SizedBox(height: 16),

                      // Weekly Challenge Card
                      _buildWeeklyChallengeCard(palette, isDark),
                      const SizedBox(height: 20),

                      // General Leaderboard (Rank 4 to 8)
                      _buildGeneralRankings(palette, isDark),
                      const SizedBox(height: 16),

                      // Micro-footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: palette.accent),
                          const SizedBox(width: 6),
                          Text(
                            'Sıralamalar her 15 dakikada bir senkronize edilir.',
                            style: SwanType.caption(palette.inkMuted),
                          ),
                        ],
                      ),
                    ],
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

  Widget _buildHeader(BuildContext context, SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: palette.line.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: palette.ink,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                'Liderlik & Ligler',
                style: SwanType.h3(palette.ink),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Sezon 4 Canlı',
                    style: SwanType.caption(palette.accent, w: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: palette.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs(SwanPalette palette) {
    final periods = ['Haftalık', 'Aylık', 'Sezonluk'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        children: [
          for (int i = 0; i < periods.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedPeriod = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedPeriod == i ? palette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: _selectedPeriod == i
                        ? [
                            BoxShadow(
                              color: palette.accent.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      periods[i],
                      style: SwanType.caption(
                        _selectedPeriod == i ? Colors.white : palette.inkMuted,
                        w: _selectedPeriod == i ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDisciplinePills(SwanPalette palette) {
    final disciplines = [
      (Icons.directions_run_rounded, 'Koşu'),
      (Icons.fitness_center_rounded, 'Ağırlık & Power'),
      (Icons.sports_martial_arts_rounded, 'Karma Atletizm'),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: disciplines.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isSelected = _selectedDiscipline == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedDiscipline = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? palette.accent.withValues(alpha: 0.15) : palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? palette.accent : palette.line,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    disciplines[i].$1,
                    size: 15,
                    color: isSelected ? palette.accent : palette.inkMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    disciplines[i].$2,
                    style: SwanType.caption(
                      isSelected ? palette.accent : palette.inkMuted,
                      w: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildElitLeagueHero(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            palette.surface,
            palette.surfaceAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.workspace_premium_rounded, size: 12, color: palette.accent),
                          const SizedBox(width: 4),
                          Text(
                            'ELİT ELMAS',
                            style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.deepOrangeAccent),
                        const SizedBox(width: 2),
                        Text(
                          'Kademe 1',
                          style: SwanType.caption(Colors.deepOrangeAccent, w: FontWeight.w700).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Swan Elit Ligi',
                  style: SwanType.h2(palette.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'En iyi %3\'lük dilimdeki sporcular yarışıyor',
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              children: [
                Text(
                  'KALAN SÜRE',
                  style: SwanType.caption(palette.inkMuted, w: FontWeight.w700).copyWith(fontSize: 9),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '04',
                      style: SwanType.body(palette.accent, w: FontWeight.w800),
                    ),
                    Text('G ', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10)),
                    Text(
                      '18',
                      style: SwanType.body(palette.accent, w: FontWeight.w800),
                    ),
                    Text('S', style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumDeck(SwanPalette palette, bool isDark) {
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];
    final first = suggestions.isNotEmpty ? suggestions[0].name : 'Lider Sporcu';
    final second = suggestions.length > 1 ? suggestions[1].name : '2. Sıra';
    final third = suggestions.length > 2 ? suggestions[2].name : '3. Sıra';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2: Silver
        Expanded(
          child: _buildPodiumItem(
            rank: 2,
            name: second,
            metric: '112.0 km',
            points: '7.150 P',
            podiumHeight: 70,
            accentColor: Colors.grey.shade400,
            icon: Icons.military_tech_rounded,
            palette: palette,
          ),
        ),
        const SizedBox(width: 8),
        // Rank 1: Gold / Champion
        Expanded(
          child: _buildPodiumItem(
            rank: 1,
            name: first,
            metric: '128.4 km',
            points: '8.420 P',
            podiumHeight: 100,
            accentColor: Colors.amber.shade600,
            icon: Icons.emoji_events_rounded,
            palette: palette,
            isFirst: true,
          ),
        ),
        const SizedBox(width: 8),
        // Rank 3: Bronze
        Expanded(
          child: _buildPodiumItem(
            rank: 3,
            name: third,
            metric: '105.8 km',
            points: '6.890 P',
            podiumHeight: 54,
            accentColor: Colors.brown.shade400,
            icon: Icons.workspace_premium_rounded,
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumItem({
    required int rank,
    required String name,
    required String metric,
    required String points,
    required double podiumHeight,
    required Color accentColor,
    required IconData icon,
    required SwanPalette palette,
    bool isFirst = false,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (isFirst) ...[
          const Icon(Icons.star_rounded, size: 24, color: Colors.amber),
          const SizedBox(height: 2),
        ],
        Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: isFirst ? 68 : 54,
              height: isFirst ? 68 : 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceAlt,
                border: Border.all(
                  color: isFirst ? palette.accent : palette.line,
                  width: isFirst ? 2.5 : 1.5,
                ),
                boxShadow: isFirst
                    ? [
                        BoxShadow(
                          color: palette.accent.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Icon(
                  Icons.person_rounded,
                  size: isFirst ? 36 : 28,
                  color: palette.inkMuted,
                ),
              ),
            ),
            Positioned(
              bottom: -8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: SwanType.caption(Colors.white, w: FontWeight.w900).copyWith(fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          metric,
          style: SwanType.caption(isFirst ? palette.accent : palette.ink, w: FontWeight.w700),
        ),
        Text(
          points,
          style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: podiumHeight,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: palette.line),
            gradient: isFirst
                ? LinearGradient(
                    colors: [palette.accent.withValues(alpha: 0.15), palette.surface],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: accentColor),
              if (isFirst) ...[
                const SizedBox(height: 2),
                Text(
                  'LİDER',
                  style: SwanType.caption(palette.accent, w: FontWeight.w900).copyWith(fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserStatusCard(SwanPalette palette, bool isDark) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final history = ref.watch(myTrainingHistoryProvider).valueOrNull ?? const [];
    final workoutCount = history.length;
    final totalScore = history.fold<double>(0.0, (sum, e) => sum + (e.totalScore ?? 0.0));
    final scoreStr = totalScore > 0 ? '${totalScore.toStringAsFixed(0)} P' : '$workoutCount Seans';
    final name = (profile?.fullName.isNotEmpty == true) ? profile!.fullName : 'Senin Durumun';
    final roleOrClub = profile?.role ?? 'SwanSport Sporcusu';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '#1',
                    style: SwanType.bodySm(palette.accent, w: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SEN',
                            style: SwanType.caption(palette.accent, w: FontWeight.w800).copyWith(fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$name • $roleOrClub',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(palette.inkMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    scoreStr,
                    style: SwanType.body(palette.accent, w: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      Icon(Icons.arrow_upward_rounded, size: 12, color: palette.success),
                      Text(
                        'Aktif',
                        style: SwanType.caption(palette.success, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 12, color: palette.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Ligde kalmak için: +8.2 km gerekli',
                    style: SwanType.caption(palette.warning, w: FontWeight.w600).copyWith(fontSize: 10),
                  ),
                ],
              ),
              Text(
                'Hedef: 82.7 km',
                style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 5,
              color: palette.surfaceAlt,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.78,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChallengeCard(SwanPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.deepOrangeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sailing_rounded,
                  size: 20,
                  color: Colors.deepOrangeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepOrangeAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MEYDAN OKUMA',
                            style: SwanType.caption(Colors.deepOrangeAccent, w: FontWeight.w800).copyWith(fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '3 Gün Kaldı',
                          style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '100K Boğaz Koşu Meydan Okuması',
                      style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.military_tech_rounded, size: 24, color: palette.accent),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tamamlanan Mesafe',
                style: SwanType.caption(palette.inkMuted),
              ),
              Text(
                '68.0 / 100.0 km (%68)',
                style: SwanType.caption(palette.accent, w: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: palette.surfaceAlt,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.68,
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ödül: Boğaz Fatihi Rozeti + 500 Puan',
                style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meydan okumaya katıldınız!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Katıl',
                    style: SwanType.caption(Colors.white, w: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralRankings(SwanPalette palette, bool isDark) {
    final suggestions = ref.watch(suggestionsProvider).valueOrNull ?? const [];
    final athletes = suggestions.skip(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Genel Sıralama',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            Text(
              'Aktif ${suggestions.length} Sporcu',
              style: SwanType.caption(palette.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (athletes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Sıralamada başka sporcu bulunmuyor.',
                style: SwanType.caption(palette.inkMuted),
              ),
            ),
          )
        else
          for (int i = 0; i < athletes.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 4}',
                      style: SwanType.bodySm(palette.inkMuted, w: FontWeight.w800),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        athletes[i].name.isNotEmpty ? athletes[i].name[0].toUpperCase() : 'S',
                        style: SwanType.bodySm(palette.accent, w: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          athletes[i].name,
                          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                        ),
                        Text(
                          athletes[i].subtitle ?? 'SwanSport Sporcusu',
                          style: SwanType.caption(palette.inkMuted).copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
