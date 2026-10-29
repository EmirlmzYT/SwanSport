import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import '../host/pro_feature_theme.dart';

typedef MarkOccupiedCallback = Future<void> Function({
  required String fieldId,
  required DateTime startsAt,
  String? note,
});

typedef MarkFreeCallback = Future<void> Function({
  required String fieldId,
  required DateTime startsAt,
});

typedef CheckConflictsCallback = Future<List<FacilitySlot>> Function({
  required String facilityId,
  required DateTime start,
  DateTime? end,
});

@immutable
final class FacilityScheduleWriteCallbacks {
  const FacilityScheduleWriteCallbacks({
    this.onMarkOccupied,
    this.onMarkFree,
    this.onCheckConflicts,
  });

  final MarkOccupiedCallback? onMarkOccupied;
  final MarkFreeCallback? onMarkFree;
  final CheckConflictsCallback? onCheckConflicts;
}

/// Halı saha doluluk çizelgesi, kulüp tesisi programı ve çakışma denetimi ekranı.
final class SharedFacilityScheduleScreen extends ConsumerWidget {
  const SharedFacilityScheduleScreen({
    this.initialCustomFacilityId,
    this.writeCallbacks = const FacilityScheduleWriteCallbacks(),
    super.key,
  });

  final String? initialCustomFacilityId;
  final FacilityScheduleWriteCallbacks writeCallbacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    return host.chrome.buildPage(
      context,
      title: 'Tesis Doluluk & Program Çizelgesi',
      body: _FacilityScheduleBody(
        initialCustomFacilityId: initialCustomFacilityId,
        writeCallbacks: writeCallbacks,
      ),
    );
  }
}

final class _FacilityScheduleBody extends ConsumerStatefulWidget {
  const _FacilityScheduleBody({
    required this.initialCustomFacilityId,
    required this.writeCallbacks,
  });

  final String? initialCustomFacilityId;
  final FacilityScheduleWriteCallbacks writeCallbacks;

  @override
  ConsumerState<_FacilityScheduleBody> createState() =>
      _FacilityScheduleBodyState();
}

final class _FacilityScheduleBodyState
    extends ConsumerState<_FacilityScheduleBody> {
  // Turf occupancy state
  TurfSlot? _selectedTurfSlot;
  bool _isSubmittingTurf = false;
  String? _turfStatusMessage;
  bool _isTurfStatusError = false;

  // Club facility conflict inspection state
  String? _selectedClubFacilityId;
  final DateTime _conflictCheckStart =
      DateTime.now().add(const Duration(hours: 1));
  final DateTime _conflictCheckEnd =
      DateTime.now().add(const Duration(hours: 2));
  bool _isCheckingConflict = false;
  String? _conflictResultStatus; // 'none', 'conflict', 'unverified'
  int _conflictCount = 0;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _selectedClubFacilityId = widget.initialCustomFacilityId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialCustomFacilityId != null) {
        _runConflictCheck(widget.initialCustomFacilityId!);
      }
    });
  }

  void _clearTurfSlotSelection() {
    setState(() {
      _selectedTurfSlot = null;
      _turfStatusMessage = null;
    });
  }

  void _clearConflictState() {
    setState(() {
      _conflictResultStatus = null;
      _conflictCount = 0;
    });
  }

  Future<void> _handleMarkOccupied({
    required String fieldId,
    required DateTime startsAt,
  }) async {
    if (_isSubmittingTurf) return;

    setState(() {
      _isSubmittingTurf = true;
      _turfStatusMessage = null;
    });

    try {
      final callback = widget.writeCallbacks.onMarkOccupied;
      if (callback != null) {
        await callback(fieldId: fieldId, startsAt: startsAt);
      } else {
        await ref.read(turfServiceProvider).markOccupied(
              fieldId: fieldId,
              startsAt: startsAt,
            );
      }

      ref.invalidate(turfOccupancyGridProvider(fieldId));

      if (!mounted) return;
      setState(() {
        _isSubmittingTurf = false;
        _selectedTurfSlot = null;
        _turfStatusMessage = 'Saat hücresi dolu olarak işaretlendi.';
        _isTurfStatusError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingTurf = false;
        _turfStatusMessage =
            'Ağ hatası veya işlem başarısız oldu. Aynı saatle tekrar deneyebilirsiniz: $e';
        _isTurfStatusError = true;
      });
    }
  }

  Future<void> _handleMarkFree({
    required String fieldId,
    required DateTime startsAt,
  }) async {
    if (_isSubmittingTurf) return;

    setState(() {
      _isSubmittingTurf = true;
      _turfStatusMessage = null;
    });

    try {
      final callback = widget.writeCallbacks.onMarkFree;
      if (callback != null) {
        await callback(fieldId: fieldId, startsAt: startsAt);
      } else {
        await ref.read(turfServiceProvider).markFree(
              fieldId: fieldId,
              startsAt: startsAt,
            );
      }

      ref.invalidate(turfOccupancyGridProvider(fieldId));

      if (!mounted) return;
      setState(() {
        _isSubmittingTurf = false;
        _selectedTurfSlot = null;
        _turfStatusMessage = 'Saat hücresi boş olarak güncellendi.';
        _isTurfStatusError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmittingTurf = false;
        _turfStatusMessage = 'İşlem başarısız oldu: $e';
        _isTurfStatusError = true;
      });
    }
  }

  Future<void> _runConflictCheck(String facilityId) async {
    if (_isCheckingConflict) return;

    // 1. UUID validation: must be a canonical UUID; free-text names are rejected
    if (!_uuidRegex.hasMatch(facilityId.trim())) {
      setState(() {
        _conflictResultStatus = 'unverified';
        _conflictCount = 0;
      });
      return;
    }

    setState(() {
      _isCheckingConflict = true;
      _conflictResultStatus = null;
    });

    // 2. Club ownership verification: must belong to the active club in facilitiesProvider
    final List<FacilityRow> facilities;
    try {
      final current = ref.read(facilitiesProvider).valueOrNull;
      facilities = current ?? await ref.read(facilitiesProvider.future);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingConflict = false;
        _conflictResultStatus = 'unverified';
        _conflictCount = 0;
      });
      return;
    }

    final belongsToActiveClub = facilities.any((f) => f.id == facilityId);
    if (!belongsToActiveClub) {
      // Prevents fake empty response from SQL RLS for foreign club facilities
      if (!mounted) return;
      setState(() {
        _isCheckingConflict = false;
        _conflictResultStatus = 'unverified';
        _conflictCount = 0;
      });
      return;
    }

    try {
      final callback = widget.writeCallbacks.onCheckConflicts;
      List<FacilitySlot> conflicts;
      if (callback != null) {
        conflicts = await callback(
          facilityId: facilityId,
          start: _conflictCheckStart,
          end: _conflictCheckEnd,
        );
      } else {
        conflicts = await ref.read(clubOpsServiceProvider).conflicts(
              facilityId: facilityId,
              start: _conflictCheckStart,
              end: _conflictCheckEnd,
            );
      }

      if (!mounted) return;
      setState(() {
        _isCheckingConflict = false;
        if (conflicts.isEmpty) {
          _conflictResultStatus = 'none';
          _conflictCount = 0;
        } else {
          _conflictResultStatus = 'conflict';
          _conflictCount = conflicts.length;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCheckingConflict = false;
        _conflictResultStatus = 'unverified';
        _conflictCount = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);

    if (flagsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final flags = flagsAsync.valueOrNull;

    // Gate A: Turf Fields
    final canOpenTurf = flags != null &&
        flags.has(FeatureFlags.turfFields) &&
        access.canOpenTurfCenter;

    // Gate B: Club Facility Conflicts
    final activeClub = ref.watch(activeClubProvider).valueOrNull;
    final canOpenClubFacilities = flags != null &&
        flags.has(FeatureFlags.facilityConflicts) &&
        access.isClubStaff &&
        activeClub != null;

    // If both gates are closed: fail-closed empty state
    if (!canOpenTurf && !canOpenClubFacilities) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 56,
                color: theme.inkMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Tesis Programı Yetkisi Yok',
                style: TextStyle(
                  color: theme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Halı saha doluluk panosu veya kulüp tesisi çakışma denetimi yetkisi bulunmuyor.',
                style: TextStyle(color: theme.inkMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Listen to scope changes to clear selections
    ref.listen(selectedFacilityScopeIdProvider, (prev, next) {
      if (prev != next) {
        _clearTurfSlotSelection();
        _clearConflictState();
      }
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canOpenTurf) ...[
          _buildTurfOccupancySection(theme, access),
          if (canOpenClubFacilities) const SizedBox(height: 28),
        ],
        if (canOpenClubFacilities) ...[
          _buildClubFacilitySection(theme, activeClub),
        ],
      ],
    );
  }

  Widget _buildTurfOccupancySection(
    ProFeatureThemeData theme,
    SwanAccess access,
  ) {
    final allTurfFieldIds = [
      ...access.managedTurfFieldIds,
      ...access.delegatedTurfFieldIds,
    ];
    final selectedFieldId = ref.watch(selectedFacilityScopeIdProvider) ??
        (allTurfFieldIds.isNotEmpty ? allTurfFieldIds.first : null);

    final canEdit =
        selectedFieldId != null && access.canEditTurfOccupancy(selectedFieldId);

    final slotsAsync = selectedFieldId != null
        ? ref.watch(turfOccupancyGridProvider(selectedFieldId))
        : null;

    return Container(
      key: const Key('turf-occupancy-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sports_soccer_rounded,
                    color: theme.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Halı Saha Doluluk Çizelgesi',
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedFieldId != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: canEdit
                        ? theme.accent.withValues(alpha: 0.15)
                        : theme.inkMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    canEdit ? 'Yetkili' : 'Salt Okunur',
                    style: TextStyle(
                      color: canEdit ? theme.accent : theme.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_turfStatusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isTurfStatusError
                    ? theme.danger.withValues(alpha: 0.1)
                    : theme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isTurfStatusError ? theme.danger : theme.accent,
                ),
              ),
              child: Text(
                _turfStatusMessage!,
                style: TextStyle(
                  color: _isTurfStatusError ? theme.danger : theme.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (slotsAsync == null)
            Text(
              'Seçili halı saha bulunmuyor.',
              style: TextStyle(color: theme.inkMuted, fontSize: 13),
            )
          else
            slotsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Text(
                'Doluluk bilgisi yüklenemedi: $err',
                style: TextStyle(color: theme.danger, fontSize: 13),
              ),
              data: (slots) {
                if (slots.isEmpty) {
                  return Text(
                    'Tanımlı saat şeridi bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 13),
                  );
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: slots.map((slot) {
                    final isSelected =
                        _selectedTurfSlot?.startsAt == slot.startsAt;
                    return InkWell(
                      key: Key('turf-slot-${slot.startsAt.toIso8601String()}'),
                      onTap: () {
                        setState(() {
                          _selectedTurfSlot = slot;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: slot.occupied
                              ? theme.danger.withValues(alpha: 0.15)
                              : theme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.ink
                                : (slot.occupied ? theme.danger : theme.accent),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${slot.hourLabel} (${slot.occupied ? "Dolu" : "Boş"})',
                          style: TextStyle(
                            color: theme.ink,
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          // Write actions: strictly hidden for users without canEditTurfOccupancy
          if (canEdit && _selectedTurfSlot != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (!_selectedTurfSlot!.occupied)
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FilledButton.tonal(
                        key: const Key('mark-occupied-btn'),
                        onPressed: _isSubmittingTurf
                            ? null
                            : () => _handleMarkOccupied(
                                  fieldId: selectedFieldId,
                                  startsAt: _selectedTurfSlot!.startsAt,
                                ),
                        child: _isSubmittingTurf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Dolu İşaretle'),
                      ),
                    ),
                  ),
                if (_selectedTurfSlot!.occupied)
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: OutlinedButton(
                        key: const Key('mark-free-btn'),
                        onPressed: _isSubmittingTurf
                            ? null
                            : () => _handleMarkFree(
                                  fieldId: selectedFieldId,
                                  startsAt: _selectedTurfSlot!.startsAt,
                                ),
                        child: _isSubmittingTurf
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Boşalt'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClubFacilitySection(
    ProFeatureThemeData theme,
    ClubRef activeClub,
  ) {
    final facilitiesAsync = ref.watch(facilitiesProvider);

    return Container(
      key: const Key('club-facility-section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.stadium_rounded, color: theme.warning, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kulüp Tesisleri & Çakışma Denetimi',
                      style: TextStyle(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                activeClub.name,
                style: TextStyle(color: theme.inkMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          facilitiesAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Text(
              'Kulüp tesisleri yüklenemedi: $err',
              style: TextStyle(color: theme.danger, fontSize: 13),
            ),
            data: (facilities) {
              if (facilities.isEmpty) {
                return Text(
                  'Kulübe ait kayıtlı tesis bulunmuyor.',
                  style: TextStyle(color: theme.inkMuted, fontSize: 13),
                );
              }

              final selectedId = _selectedClubFacilityId ?? facilities.first.id;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    key: const Key('club-facility-dropdown'),
                    isExpanded: true,
                    initialValue: facilities.any((f) => f.id == selectedId)
                        ? selectedId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Denetlenecek Kulüp Tesisi',
                      filled: true,
                      fillColor: theme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: facilities.map((f) {
                      return DropdownMenuItem<String>(
                        value: f.id,
                        child: Text(
                          '${f.name} (${f.status})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        setState(() {
                          _selectedClubFacilityId = newId;
                        });
                        _runConflictCheck(newId);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: double.infinity,
                    ),
                    child: FilledButton.icon(
                      key: const Key('check-facility-conflicts-btn'),
                      onPressed: _isCheckingConflict
                          ? null
                          : () => _runConflictCheck(selectedId),
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: const Text('Çakışma Denetimi Yap'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildConflictResultBanner(theme),
        ],
      ),
    );
  }

  Widget _buildConflictResultBanner(ProFeatureThemeData theme) {
    if (_isCheckingConflict) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_conflictResultStatus == null) {
      return const SizedBox.shrink();
    }

    final (color, text) = switch (_conflictResultStatus) {
      'none' => (theme.success, 'Kayıtlı çakışma yok'),
      'conflict' => (
          theme.danger,
          'Çakışma mevcut ($_conflictCount kayıt)',
        ),
      _ => (theme.warning, 'Doğrulanamıyor'),
    };

    return Container(
      key: const Key('conflict-result-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            _conflictResultStatus == 'none'
                ? Icons.check_circle_outline_rounded
                : (_conflictResultStatus == 'conflict'
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
