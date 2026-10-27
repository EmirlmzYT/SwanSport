import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';

/// Tesis ve Halı Saha Operasyonları Çalışma Alanı Paneli.
///
/// Yalnızca `SwanAccess.canOpenTurfCenter` yetkisi olan yöneticiler ve
/// delegeler için açılır.
final class SharedFacilityOperationsPanel extends ConsumerStatefulWidget {
  const SharedFacilityOperationsPanel({super.key});

  @override
  ConsumerState<SharedFacilityOperationsPanel> createState() =>
      _SharedFacilityOperationsPanelState();
}

final class _SharedFacilityOperationsPanelState
    extends ConsumerState<SharedFacilityOperationsPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initScopeIfNeeded();
    });
  }

  void _initScopeIfNeeded() {
    final access = ref.read(swanAccessProvider);
    final allFieldIds = {
      ...access.managedTurfFieldIds,
      ...access.delegatedTurfFieldIds,
    };
    final currentScope = ref.read(selectedFacilityScopeIdProvider);
    if ((currentScope == null || !allFieldIds.contains(currentScope)) &&
        allFieldIds.isNotEmpty) {
      ref.read(selectedFacilityScopeIdProvider.notifier).state =
          allFieldIds.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);

    if (!access.canOpenTurfCenter) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.stadium_outlined, size: 56, color: theme.inkMuted),
            const SizedBox(height: 16),
            Text(
              'Tesis Operasyonları Yetkisi Yok',
              style: TextStyle(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Bu çalışma alanı halı saha yöneticilerine veya süreli saha görevlilerine açıktır.',
              style: TextStyle(color: theme.inkMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final flags = flagsAsync.valueOrNull;
    final isFlagsDisabled = flags == null ||
        !flags.has(FeatureFlags.turfFields) ||
        !flags.has(FeatureFlags.turfDelegation);

    if (isFlagsDisabled) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, color: theme.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tesis operasyonları özelliği etkin değil.',
                style: TextStyle(
                  color: theme.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final allFieldIds = [
      ...access.managedTurfFieldIds,
      ...access.delegatedTurfFieldIds,
    ];
    final selectedFieldId = ref.watch(selectedFacilityScopeIdProvider) ??
        (allFieldIds.isNotEmpty ? allFieldIds.first : null);

    final fieldsAsync = ref.watch(turfFieldsProvider(null));
    final fieldsList = fieldsAsync.valueOrNull ?? const <TurfField>[];
    final fieldMap = {for (final f in fieldsList) f.id: f};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScopeSelector(
            context: context,
            theme: theme,
            access: access,
            allFieldIds: allFieldIds,
            selectedFieldId: selectedFieldId,
            fieldMap: fieldMap,
          ),
          const SizedBox(height: 20),
          _buildWorkspaceCards(context, theme, selectedFieldId),
        ],
      ),
    );
  }

  Widget _buildScopeSelector({
    required BuildContext context,
    required ProFeatureThemeData theme,
    required SwanAccess access,
    required List<String> allFieldIds,
    required String? selectedFieldId,
    required Map<String, TurfField> fieldMap,
  }) {
    return Container(
      key: const Key('facility-scope-selector-container'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, color: theme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Aktif Tesis Kapsamı',
                style: TextStyle(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('facility-scope-selector'),
            initialValue: selectedFieldId,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: theme.line),
              ),
            ),
            items: allFieldIds.map((id) {
              final field = fieldMap[id];
              final isManager = access.managedTurfFieldIds.contains(id);
              final displayName = field != null
                  ? '${field.venueName} · ${field.name}'
                  : 'Saha: $id';
              final roleLabel = isManager ? 'Yönetici' : 'Görevli Delege';
              final roleColor = isManager ? theme.accent : theme.inkMuted;

              return DropdownMenuItem<String>(
                value: id,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newFieldId) {
              if (newFieldId != null && newFieldId != selectedFieldId) {
                ref.read(selectedFacilityScopeIdProvider.notifier).state =
                    newFieldId;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceCards(
    BuildContext context,
    ProFeatureThemeData theme,
    String? selectedFieldId,
  ) {
    final host = ProFeatureHostScope.of(context);

    return Column(
      children: [
        _buildActionCard(
          theme: theme,
          icon: Icons.badge_outlined,
          title: 'Süreli Saha Görevleri',
          subtitle:
              'Geçici nöbet atamaları, kabul bekleyen davetler ve aktif görevler.',
          actionLabel: 'Görevleri Yönet',
          onTap: () {
            host.navigator.openFacilityOperations();
          },
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          theme: theme,
          icon: Icons.calendar_month_outlined,
          title: 'Halı Saha Doluluk Çizelgesi',
          subtitle:
              'Haftalık saat şeridi doluluk işaretleme ve müsaitlik panosu.',
          actionLabel: 'Çizelgeyi Aç (Faz 3b)',
          onTap: () {},
          isPlaceholder: true,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          theme: theme,
          icon: Icons.schedule_send_outlined,
          title: 'Rezervasyon Talepleri',
          subtitle: 'Kullanıcılardan gelen saat istekleri ve onay durumu.',
          actionLabel: 'Talepleri İncele (Faz 3c)',
          onTap: () {},
          isPlaceholder: true,
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required ProFeatureThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onTap,
    bool isPlaceholder = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPlaceholder ? theme.inkMuted : theme.accent)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isPlaceholder ? theme.inkMuted : theme.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: theme.inkMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isPlaceholder ? null : onTap,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
