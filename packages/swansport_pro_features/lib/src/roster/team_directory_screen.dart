import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import 'team_directory_content.dart';

final class SharedTeamDirectoryScreen extends ConsumerWidget {
  const SharedTeamDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final flags = ref.watch(featureFlagsProvider);
    if (flags.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Takımlar & Kadrolar',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final enabled = ref.watch(
      featureEnabledProvider(FeatureFlags.teamHub),
    );
    if (!enabled) {
      return host.chrome.buildPage(
        context,
        title: 'Takımlar & Kadrolar',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Takım merkezi şu anda kullanıma kapalı.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final club = ref.watch(activeClubProvider).valueOrNull;
    final canManage =
        club != null && (club.role == 'club_admin' || club.role == 'coach');
    return host.chrome.buildPage(
      context,
      title: 'Takımlar & Kadrolar',
      actions: [
        if (canManage)
          IconButton(
            tooltip: 'Takım Ekle',
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
            ),
            icon: Icon(Icons.add_rounded, color: host.theme.inkMuted),
            onPressed: () => _createTeam(context, ref, club.id),
          ),
      ],
      body: ColoredBox(
        color: host.theme.background,
        child: TeamDirectoryContent(
          teams: ref.watch(teamsProvider),
          theme: host.theme,
          onOpenRoster: (team) => host.navigator.openRoster(
            TeamRouteTarget(teamId: team.id, teamName: team.name),
          ),
          onOpenAttendance: host.navigator.openAttendance,
        ),
      ),
    );
  }

  Future<void> _createTeam(
    BuildContext context,
    WidgetRef ref,
    String clubId,
  ) async {
    final input = await _showTeamDialog(context);
    if (input == null || !context.mounted) return;
    final host = ProFeatureHostScope.of(context);
    try {
      await ref.read(teamCreateCommandProvider)(
        clubId,
        input.name,
        ageGroup: input.ageGroup,
        gender: input.gender,
      );
      ref.invalidate(teamsProvider);
      if (context.mounted) {
        host.chrome.showMessage(
          context,
          'Takım oluşturuldu.',
          tone: ProFeatureMessageTone.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        host.chrome.showMessage(
          context,
          classifyOperationError(error).userMessage,
          tone: ProFeatureMessageTone.danger,
        );
      }
    }
  }
}

Future<_TeamInput?> _showTeamDialog(BuildContext context) async {
  return showDialog<_TeamInput>(
    context: context,
    builder: (dialogContext) => const _TeamDialog(),
  );
}

final class _TeamDialog extends StatefulWidget {
  const _TeamDialog();

  @override
  State<_TeamDialog> createState() => _TeamDialogState();
}

final class _TeamDialogState extends State<_TeamDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _gender = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _gender.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni Takım Oluştur'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('team-name-field'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Takım adı'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Takım adı gerekli'
                      : null,
                ),
                TextFormField(
                  key: const Key('team-age-field'),
                  controller: _age,
                  decoration: const InputDecoration(labelText: 'Yaş grubu'),
                ),
                TextFormField(
                  key: const Key('team-gender-field'),
                  controller: _gender,
                  decoration: const InputDecoration(labelText: 'Cinsiyet'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (!(_formKey.currentState?.validate() ?? false)) return;
              Navigator.pop(
                context,
                _TeamInput(
                  name: _name.text.trim(),
                  ageGroup: _optional(_age.text),
                  gender: _optional(_gender.text),
                ),
              );
            },
            child: const Text('Oluştur'),
          ),
        ],
      );
}

String? _optional(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

final class _TeamInput {
  const _TeamInput({
    required this.name,
    required this.ageGroup,
    required this.gender,
  });

  final String name;
  final String? ageGroup;
  final String? gender;
}
