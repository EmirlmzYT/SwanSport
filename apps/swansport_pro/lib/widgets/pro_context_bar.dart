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
              child: InkWell(
                onTap: (workspace.supportsClubOperations && clubs.length > 1)
                    ? () => _showMobileClubPicker(context, ref, clubs)
                    : null,
                borderRadius: BorderRadius.circular(6),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              scopeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: ProTheme.muted,
                              ),
                            ),
                          ),
                          if (workspace.supportsClubOperations &&
                              clubs.length > 1) ...[
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.unfold_more_rounded,
                              size: 13,
                              color: ProTheme.primary,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (workspace.supportsClubOperations && clubs.length > 1) ...[
              IconButton(
                key: const Key('pro-mobile-club-selector-button'),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.all(12),
                ),
                tooltip: 'Kulüp Değiştir',
                icon: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 20,
                  color: ProTheme.primary,
                ),
                onPressed: () => _showMobileClubPicker(context, ref, clubs),
              ),
              const SizedBox(width: 4),
            ],
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

  void _showMobileClubPicker(
    BuildContext context,
    WidgetRef ref,
    List<ClubRef> clubs,
  ) {
    final selectedId = ref.read(selectedClubIdProvider);
    final selected =
        clubs.where((c) => c.id == selectedId).firstOrNull ?? clubs.first;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: ProTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: ProTheme.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Kulüp Değiştir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ProTheme.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final club in clubs) ...[
                          Material(
                            color: club.id == selected.id
                                ? ProTheme.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                Navigator.pop(sheetContext);
                                if (club.id != selected.id) {
                                  final coordinator = ref
                                      .read(proDirtyStateCoordinatorProvider);
                                  await coordinator.runGuardedTransition(
                                    confirmDiscard: () =>
                                        _confirmDiscard(context),
                                    invalidate: () =>
                                        invalidateProFeatureState(ref),
                                    transition: () {
                                      ref
                                          .read(selectedClubIdProvider.notifier)
                                          .state = club.id;
                                    },
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: club.id == selected.id
                                        ? ProTheme.primary
                                            .withValues(alpha: 0.35)
                                        : ProTheme.line,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: ProTheme.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.shield_outlined,
                                        size: 18,
                                        color: ProTheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            club.name,
                                            style: const TextStyle(
                                              color: ProTheme.ink,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (club.role != null &&
                                              club.role!.isNotEmpty)
                                            Text(
                                              club.role!,
                                              style: const TextStyle(
                                                color: ProTheme.muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (club.id == selected.id)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: ProTheme.primary,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDiscard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kaydedilmemiş değişiklikler var'),
          content: const Text(
            'Kulüp değiştirildiğinde kaydedilmemiş işlemler bırakılır.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kulübü değiştir'),
            ),
          ],
        ),
      ) ??
      false;
}
