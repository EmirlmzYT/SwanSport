import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../app/pro_theme.dart';
import '../features/operations/pro_club_context_selector.dart';
import '../features/operations/pro_tasks_controller.dart';
import '../workspaces/pro_workspace_controller.dart';
import '../workspaces/pro_workspace_switcher.dart';

/// Workspace ve aktif kurum/kapsamı tek bir erişilebilir bar içinde birleştiren bileşen.
class ProContextBar extends ConsumerWidget {
  const ProContextBar({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    if (workspace == null) return const SizedBox.shrink();

    final activeClub = ref.watch(activeClubProvider).valueOrNull;
    final clubs = ref.watch(proAuthorizedClubsProvider).valueOrNull ?? const [];

    String? scopeLabel;
    if (workspace.supportsClubOperations) {
      scopeLabel =
          activeClub?.name ?? (clubs.isNotEmpty ? clubs.first.name : null);
    } else if (workspace.supportsFederationOperations) {
      final scopes =
          ref.watch(federationConsoleScopesProvider).valueOrNull ?? const [];
      final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
      final activeScope = scopes
              .where((s) => federationScopeKey(s) == selectedKey)
              .firstOrNull ??
          scopes.firstOrNull;
      if (activeScope != null) {
        scopeLabel = '${activeScope.name} (${activeScope.sportCode})';
      }
    } else if (workspace.supportsRefereeOperations) {
      scopeLabel = 'Resmî Hakem Görevleri';
    } else if (workspace.supportsAccountingOperations) {
      final accClubs = ref.watch(myClubsProvider).valueOrNull ?? const [];
      final selectedId = ref.watch(selectedAccountantClubIdProvider);
      final accClub = accClubs.where((c) => c.id == selectedId).firstOrNull ??
          accClubs.firstOrNull;
      if (accClub != null) {
        scopeLabel = '${accClub.name} Muhasebesi';
      }
    } else if (workspace.supportsFacilityOperations) {
      scopeLabel = 'Tesis Operasyonları';
    } else if (workspace.supportsPlatformOperations) {
      scopeLabel = 'Sistem Yönetimi';
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: ProTheme.surface,
          border: Border(bottom: BorderSide(color: ProTheme.line)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: ProTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(workspace.icon, size: 16, color: ProTheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    workspace.label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ProTheme.ink,
                    ),
                  ),
                  if (scopeLabel != null)
                    Text(
                      scopeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: ProTheme.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const ProWorkspaceSwitcher(),
          ],
        ),
      );
    }

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: ProTheme.background,
        border: Border(bottom: BorderSide(color: ProTheme.line)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ProTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(workspace.icon, size: 20, color: ProTheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${workspace.label} Merkezi',
                style: const TextStyle(
                  color: ProTheme.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (scopeLabel != null)
                Text(
                  scopeLabel,
                  style: const TextStyle(
                    color: ProTheme.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (workspace.supportsClubOperations && clubs.length > 1) ...[
            const SizedBox(width: 220, child: ProClubContextSelector()),
            const SizedBox(width: 12),
          ],
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh_rounded,
                size: 20, color: ProTheme.muted),
            onPressed: () {
              ref.invalidateSwanAccess();
              invalidateProFeatureState(ref);
              refreshProWorkspaceData(ref, workspace);
            },
          ),
          const SizedBox(width: 8),
          const ProWorkspaceSwitcher(),
        ],
      ),
    );
  }
}
