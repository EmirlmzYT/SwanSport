import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';
import '../app/pro_theme.dart';
import 'pro_workspace.dart';
import 'pro_workspace_controller.dart';

class ProWorkspaceSwitcher extends ConsumerWidget {
  const ProWorkspaceSwitcher({super.key});

  Future<void> _performTransition(
    BuildContext context,
    WidgetRef ref,
    ProWorkspace workspace,
  ) async {
    await ref.read(proDirtyStateCoordinatorProvider).runGuardedTransition(
          confirmDiscard: () => ProFeatureHostScope.of(context).chrome.confirm(
                context,
                title: 'Kaydedilmemiş değişiklikler var',
                message:
                    'Çalışma alanı değiştirildiğinde kaydedilmemiş operasyon verileri bırakılır.',
                confirmLabel: 'Alanı değiştir',
              ),
          invalidate: () => invalidateProFeatureState(ref),
          transition: () {
            ref
                .read(selectedProWorkspaceProvider.notifier)
                .selectWorkspace(workspace);
            ref.read(selectedClubIdProvider.notifier).state = null;
            ref.read(selectedFederationScopeKeyProvider.notifier).state = null;
          },
        );
  }

  void _showMobileBottomSheet(
    BuildContext context,
    WidgetRef ref,
    List<ProWorkspace> available,
    ProWorkspace selected,
  ) {
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
                    'Çalışma Alanı Değiştir',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ProTheme.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final ws in available) ...[
                  _WorkspaceSheetTile(
                    workspace: ws,
                    isSelected: ws == selected,
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      if (ws != selected) {
                        await _performTransition(context, ref, ws);
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(availableProWorkspacesProvider);
    final selected = ref.watch(selectedProWorkspaceProvider);

    if (selected == null) {
      return const SizedBox.shrink();
    }

    // Tek çalışma alanı varsa seçici affordance'ı gizlenir
    if (available.length <= 1) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(selected.icon, size: 18, color: ProTheme.primary),
          const SizedBox(width: 8),
          Text(
            selected.label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ProTheme.ink,
            ),
          ),
        ],
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 960;

    // Masaüstünde menü/popover, mobilde modal bottom sheet
    if (!isDesktop) {
      return Semantics(
        button: true,
        label: 'Çalışma alanı değiştir, aktif: ${selected.label}',
        child: Material(
          color: ProTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            key: const ValueKey('pro_workspace_dropdown_button'),
            borderRadius: BorderRadius.circular(10),
            onTap: () =>
                _showMobileBottomSheet(context, ref, available, selected),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: ProTheme.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected.icon, size: 17, color: ProTheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    selected.label,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: ProTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: ProTheme.muted),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Masaüstü zengin PopupMenu
    return PopupMenuButton<ProWorkspace>(
      key: const ValueKey('pro_workspace_dropdown_button'),
      tooltip: 'Çalışma Alanı Değiştir',
      onSelected: (workspace) async {
        if (workspace != selected) {
          await _performTransition(context, ref, workspace);
        }
      },
      color: ProTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: ProTheme.line),
      ),
      itemBuilder: (context) {
        return available.map((ws) {
          final isCurrent = ws == selected;
          return PopupMenuItem<ProWorkspace>(
            value: ws,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? ProTheme.primary.withValues(alpha: 0.15)
                          : ProTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      ws.icon,
                      size: 18,
                      color: isCurrent ? ProTheme.primary : ProTheme.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ws.label,
                          style: TextStyle(
                            color: isCurrent ? ProTheme.ink : ProTheme.muted,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          ws.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ProTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isCurrent)
                    const Icon(Icons.check_rounded,
                        size: 18, color: ProTheme.primary),
                ],
              ),
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: ProTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ProTheme.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected.icon, size: 18, color: ProTheme.primary),
            const SizedBox(width: 8),
            Text(
              selected.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: ProTheme.ink,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: ProTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSheetTile extends StatelessWidget {
  const _WorkspaceSheetTile({
    required this.workspace,
    required this.isSelected,
    required this.onTap,
  });

  final ProWorkspace workspace;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${workspace.label}, ${workspace.description}',
      child: Material(
        color: isSelected
            ? ProTheme.primary.withValues(alpha: 0.12)
            : ProTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? ProTheme.primary.withValues(alpha: 0.40)
                    : ProTheme.line,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? ProTheme.primary.withValues(alpha: 0.18)
                        : ProTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    workspace.icon,
                    size: 20,
                    color: isSelected ? ProTheme.primary : ProTheme.muted,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        workspace.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? ProTheme.ink : ProTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workspace.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: ProTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
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
    );
  }
}
