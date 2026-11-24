import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_theme.dart';

enum _TeamFilter { all, competition, youth }

final class TeamDirectoryContent extends StatefulWidget {
  const TeamDirectoryContent({
    required this.teams,
    required this.theme,
    required this.onOpenRoster,
    required this.onOpenAttendance,
    super.key,
  });

  final AsyncValue<List<TeamRow>> teams;
  final ProFeatureThemeData theme;
  final ValueChanged<TeamRow> onOpenRoster;
  final VoidCallback onOpenAttendance;

  @override
  State<TeamDirectoryContent> createState() => _TeamDirectoryContentState();
}

final class _TeamDirectoryContentState extends State<TeamDirectoryContent> {
  _TeamFilter _filter = _TeamFilter.all;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final rows = widget.teams.valueOrNull ?? const <TeamRow>[];
    final youthCount =
        rows.where((team) => team.ageGroup?.trim().isNotEmpty ?? false).length;
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            children: [
              _DirectoryHero(
                teamCount: rows.length,
                youthCount: youthCount,
                loading: widget.teams.isLoading,
                theme: widget.theme,
              ),
              const SizedBox(height: 16),
              _SearchField(
                theme: widget.theme,
                onChanged: (value) => setState(
                  () => _searchQuery = value.trim().toLowerCase(),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('Tümü', _TeamFilter.all),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Yarışma Kadroları',
                      _TeamFilter.competition,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      'Altyapı & Hazırlık',
                      _TeamFilter.youth,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              widget.teams.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => _MessageState(
                  icon: Icons.error_outline_rounded,
                  message: classifyOperationError(error).userMessage,
                  color: widget.theme.danger,
                ),
                data: _buildTeams,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, _TeamFilter value) => ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: widget.theme.accent,
        backgroundColor: widget.theme.surface,
        side: BorderSide(
          color: _filter == value ? widget.theme.accent : widget.theme.line,
        ),
        labelStyle: TextStyle(
          color:
              _filter == value ? widget.theme.surface : widget.theme.inkMuted,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _buildTeams(List<TeamRow> teams) {
    if (teams.isEmpty) {
      return _MessageState(
        icon: Icons.shield_outlined,
        message: 'Henüz oluşturulmuş bir takım bulunmuyor.',
        color: widget.theme.inkMuted,
      );
    }

    final filtered = teams.where((team) {
      final matchesSearch = _searchQuery.isEmpty ||
          team.name.toLowerCase().contains(_searchQuery) ||
          (team.ageGroup?.toLowerCase().contains(_searchQuery) ?? false);
      if (!matchesSearch) return false;
      return switch (_filter) {
        _TeamFilter.all => true,
        _TeamFilter.competition => team.ageGroup?.trim().isEmpty ?? true,
        _TeamFilter.youth => team.ageGroup?.trim().isNotEmpty ?? false,
      };
    }).toList();

    if (filtered.isEmpty) {
      return _MessageState(
        icon: Icons.search_off_rounded,
        message: 'Aramana uygun takım bulunamadı.',
        color: widget.theme.inkMuted,
      );
    }

    return Column(
      children: [
        for (final team in filtered)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TeamCard(
              team: team,
              theme: widget.theme,
              onOpenRoster: () => widget.onOpenRoster(team),
              onOpenAttendance: widget.onOpenAttendance,
            ),
          ),
      ],
    );
  }
}

final class _DirectoryHero extends StatelessWidget {
  const _DirectoryHero({
    required this.teamCount,
    required this.youthCount,
    required this.loading,
    required this.theme,
  });

  final int teamCount;
  final int youthCount;
  final bool loading;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.accent.withValues(alpha: .3)),
          boxShadow: [
            BoxShadow(
              color: theme.ink.withValues(alpha: .04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: theme.accent, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'TAKIM OPERASYONLARI',
                    style: TextStyle(
                      color: theme.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Takımları ve kadroları yönet',
              style: TextStyle(
                color: theme.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Yarışma ve altyapı ekiplerini bul, kadroya gir ve yoklamaya geç.',
              style: TextStyle(color: theme.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DirectoryMetric(
                  icon: Icons.groups_2_outlined,
                  label: loading ? 'Yükleniyor' : '$teamCount takım',
                  theme: theme,
                ),
                _DirectoryMetric(
                  icon: Icons.school_outlined,
                  label: '$youthCount altyapı',
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      );
}

final class _DirectoryMetric extends StatelessWidget {
  const _DirectoryMetric({
    required this.icon,
    required this.label,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: theme.accent),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

final class _SearchField extends StatelessWidget {
  const _SearchField({required this.theme, required this.onChanged});

  final ProFeatureThemeData theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        onChanged: onChanged,
        style: TextStyle(color: theme.ink),
        decoration: InputDecoration(
          hintText: 'Takım adı veya yaş grubu ara...',
          hintStyle: TextStyle(color: theme.inkMuted),
          prefixIcon: Icon(Icons.search_rounded, color: theme.accent),
          filled: true,
          fillColor: theme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: theme.accent, width: 2),
          ),
        ),
      );
}

final class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.theme,
    required this.onOpenRoster,
    required this.onOpenAttendance,
  });

  final TeamRow team;
  final ProFeatureThemeData theme;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      team.ageGroup,
      team.gender,
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.line),
        boxShadow: [
          BoxShadow(
            color: theme.ink.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(
                      Icons.shield_outlined,
                      color: theme.accent,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.name,
                        style: TextStyle(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isEmpty ? 'Standart Takım Kadrosu' : subtitle,
                        style: TextStyle(color: theme.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _StatusChip(theme: theme),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.5;
                final rosterButton = OutlinedButton.icon(
                  onPressed: onOpenRoster,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.accent,
                    side: BorderSide(color: theme.accent),
                  ),
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('Kadroyu İncele'),
                );
                final attendanceButton = FilledButton.icon(
                  onPressed: onOpenAttendance,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.accent,
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Yoklama Al'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      rosterButton,
                      const SizedBox(height: 8),
                      attendanceButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: rosterButton),
                    const SizedBox(width: 8),
                    Expanded(child: attendanceButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.theme});

  final ProFeatureThemeData theme;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: theme.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'Aktif',
            style: TextStyle(
              color: theme.success,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

final class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      );
}
