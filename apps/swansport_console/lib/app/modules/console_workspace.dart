import 'package:flutter/material.dart';
import '../preferences/console_preferences.dart';
import 'package:swansport_data/swansport_data.dart';

import 'console_module.dart';
import 'module_registry.dart';

/// Presentation context only. Module visibility and server permissions remain
/// authoritative; choosing a workspace never grants access.
enum ConsoleWorkspace { club, federation, referee, platform }

extension ConsoleWorkspacePresentation on ConsoleWorkspace {
  String get label => switch (this) {
        ConsoleWorkspace.club => 'Kulüp',
        ConsoleWorkspace.federation => 'Federasyon',
        ConsoleWorkspace.referee => 'Hakemlik',
        ConsoleWorkspace.platform => 'Platform',
      };

  IconData get icon => switch (this) {
        ConsoleWorkspace.club => Icons.shield_outlined,
        ConsoleWorkspace.federation => Icons.account_balance_outlined,
        ConsoleWorkspace.referee => Icons.sports_score_outlined,
        ConsoleWorkspace.platform => Icons.layers_outlined,
      };

  bool contains(ConsoleModule module) => switch (this) {
        ConsoleWorkspace.club =>
          module.audience.contains(ConsoleAudience.clubStaff) ||
              module.audience.contains(ConsoleAudience.accountant),
        ConsoleWorkspace.federation =>
          module.audience.contains(ConsoleAudience.federation),
        ConsoleWorkspace.referee =>
          module.audience.contains(ConsoleAudience.referee),
        ConsoleWorkspace.platform =>
          module.audience.contains(ConsoleAudience.platformAdmin),
      };
}

final consoleWorkspaceProvider = consolePreference<ConsoleWorkspace?>(
    'workspace',
    fallback: () => null,
    decode: (v) =>
        ConsoleWorkspace.values.where((w) => w.name == v).firstOrNull,
    encode: (v) => v?.name);

List<ConsoleModule> workspaceModules(
        SwanAccess access, ConsoleWorkspace workspace) =>
    kConsoleModules
        .where((m) => workspace.contains(m) && m.visibleTo(access))
        .toList();

List<ConsoleWorkspace> consoleWorkspaces(SwanAccess access) =>
    ConsoleWorkspace.values
        .where((w) => workspaceModules(access, w).isNotEmpty)
        .toList();

ConsoleWorkspace? resolveConsoleWorkspace(
    SwanAccess access, ConsoleWorkspace? preferred, String route) {
  final available = consoleWorkspaces(access);
  // A bookmark or browser back must reveal the menu containing that page.
  for (final workspace in available) {
    if (workspaceModules(access, workspace)
        .any((m) => route == m.route || route.startsWith('${m.route}/'))) {
      return workspace;
    }
  }
  if (available.contains(preferred)) return preferred;
  return available.isEmpty ? null : available.first;
}

String consoleModuleGroup(ConsoleModule module) {
  if (module.audience.contains(ConsoleAudience.accountant)) return 'MALİ İŞLER';
  if (module.audience.contains(ConsoleAudience.clubStaff)) {
    return switch (module.id) {
      'athletes' ||
      'eligibility' ||
      'club_sporting' ||
      'club_health_operations' =>
        'KADRO',
      _ => 'OPERASYON',
    };
  }
  if (module.audience.contains(ConsoleAudience.platformAdmin)) {
    return switch (module.id) {
      'mission_control' || 'flags' || 'diagnostics' || 'metrics' => 'SİSTEM',
      'courts' || 'turf_fields' || 'marketplace' => 'SPOR AĞI',
      _ => 'YÖNETİM',
    };
  }
  return 'MÜSABAKALAR';
}
