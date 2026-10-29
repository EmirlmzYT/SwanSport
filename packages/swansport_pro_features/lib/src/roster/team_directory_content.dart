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
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
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

  Widget _filterChip(String label, _TeamFilter value) => ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: widget.theme.accent.withValues(alpha: 0.14),
        side: BorderSide(
          color: _filter == value ? widget.theme.accent : widget.theme.line,
        ),
        labelStyle: TextStyle(
          color: _filter == value ? widget.theme.accent : widget.theme.inkMuted,
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
          prefixIcon: Icon(Icons.search, color: theme.inkMuted),
          filled: true,
          fillColor: theme.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.line),
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onOpenRoster,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accent,
                      side: BorderSide(color: theme.accent),
                    ),
                    child: const Text('Kadroyu İncele'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onOpenAttendance,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.accent,
                    ),
                    child: const Text('Yoklama Al'),
                  ),
                ),
              ],
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
