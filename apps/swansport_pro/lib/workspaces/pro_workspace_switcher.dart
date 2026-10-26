import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pro_workspace.dart';
import 'pro_workspace_controller.dart';

class ProWorkspaceSwitcher extends ConsumerWidget {
  const ProWorkspaceSwitcher({super.key});

  IconData _iconForWorkspace(ProWorkspace ws) {
    return switch (ws) {
      ProWorkspace.club => Icons.shield_outlined,
      ProWorkspace.coaching => Icons.sports_outlined,
      ProWorkspace.federation => Icons.account_balance_outlined,
      ProWorkspace.referee => Icons.sports_score_outlined,
      ProWorkspace.accounting => Icons.receipt_long_outlined,
      ProWorkspace.facility => Icons.stadium_outlined,
      ProWorkspace.platform => Icons.admin_panel_settings_outlined,
    };
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
          Icon(_iconForWorkspace(selected), size: 18, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          Text(
            selected.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      );
    }

    // Çoklu çalışma alanı varsa seçici butonu gösterilir
    return PopupMenuButton<ProWorkspace>(
      key: const ValueKey('pro_workspace_dropdown_button'),
      tooltip: 'Çalışma Alanı Değiştir',
      onSelected: (workspace) {
        ref.read(selectedProWorkspaceProvider.notifier).selectWorkspace(workspace);
      },
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      itemBuilder: (context) {
        return available.map((ws) {
          final isCurrent = ws == selected;
          return PopupMenuItem<ProWorkspace>(
            value: ws,
            child: Row(
              children: [
                Icon(
                  _iconForWorkspace(ws),
                  size: 20,
                  color: isCurrent ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ws.label,
                    style: TextStyle(
                      color: isCurrent ? Colors.white : const Color(0xFFCBD5E1),
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isCurrent)
                  const Icon(Icons.check, size: 16, color: Color(0xFF38BDF8)),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForWorkspace(selected), size: 18, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            Text(
              selected.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
