import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';

/// Kulüp tesislerine ait aktif ve bekleyen rezervasyonlar ekranı.
/// Kişisel verileri (reserved_by_phone, reserved_by_name) içermez; salt okunur çalışır.
final class SharedFacilityReservationsScreen extends ConsumerStatefulWidget {
  const SharedFacilityReservationsScreen({
    this.initialFacilityId,
    super.key,
  });

  final String? initialFacilityId;

  @override
  ConsumerState<SharedFacilityReservationsScreen> createState() =>
      _SharedFacilityReservationsScreenState();
}

final class _SharedFacilityReservationsScreenState
    extends ConsumerState<SharedFacilityReservationsScreen> {
  String? _selectedFacilityId;

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  void initState() {
    super.initState();
    _selectedFacilityId = widget.initialFacilityId;
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);
    final activeClubAsync = ref.watch(activeClubProvider);

    if (flagsAsync.isLoading || activeClubAsync.isLoading) {
      return host.chrome.buildPage(
        context,
        title: 'Aktif ve Bekleyen Rezervasyonlar',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final flags = flagsAsync.valueOrNull;
    final activeClub = activeClubAsync.valueOrNull;

    final canOpen = flags != null &&
        flags.has(FeatureFlags.facilityConflicts) &&
        access.isClubStaff &&
        activeClub != null;

    if (!canOpen) {
      return host.chrome.buildPage(
        context,
        title: 'Aktif ve Bekleyen Rezervasyonlar',
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 56,
                  color: theme.inkMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'Rezervasyon Yetkisi Yok',
                  style: TextStyle(
                    color: theme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kulüp tesisi rezervasyonlarını görüntüleme yetkisi bulunmuyor.',
                  style: TextStyle(color: theme.inkMuted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final facilitiesAsync = ref.watch(facilitiesProvider);

    return host.chrome.buildPage(
      context,
      title: 'Aktif ve Bekleyen Rezervasyonlar',
      body: facilitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Kulüp tesisleri yüklenemedi: $err',
            style: TextStyle(color: theme.danger, fontSize: 13),
          ),
        ),
        data: (facilities) {
          if (facilities.isEmpty) {
            return Center(
              child: Text(
                'Kulübe ait kayıtlı tesis bulunmuyor.',
                style: TextStyle(color: theme.inkMuted, fontSize: 13),
              ),
            );
          }

          final selectedId = _selectedFacilityId ?? facilities.first.id;
          final isValidUuid = _uuidRegex.hasMatch(selectedId.trim());
          final belongsToClub = facilities.any((f) => f.id == selectedId);

          if (!isValidUuid || !belongsToClub) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFacilityDropdown(theme, facilities, selectedId),
                const SizedBox(height: 16),
                _buildUnverifiedBanner(theme),
              ],
            );
          }

          final reservationsAsync =
              ref.watch(narrowFacilityReservationsProvider(selectedId));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFacilityDropdown(theme, facilities, selectedId),
              const SizedBox(height: 16),
              reservationsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.danger),
                  ),
                  child: Text(
                    'Rezervasyonlar yüklenemedi: $err',
                    style: TextStyle(color: theme.danger, fontSize: 13),
                  ),
                ),
                data: (reservations) {
                  if (reservations.isEmpty) {
                    return Container(
                      key: const Key('empty-reservations-banner'),
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_available_rounded,
                            size: 48,
                            color: theme.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Kayıtlı rezervasyon yok',
                            style: TextStyle(
                              color: theme.ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: reservations.map((res) {
                      return _buildReservationCard(theme, res);
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFacilityDropdown(
    ProFeatureThemeData theme,
    List<FacilityRow> facilities,
    String selectedId,
  ) {
    return DropdownButtonFormField<String>(
      key: const Key('facility-reservations-dropdown'),
      isExpanded: true,
      initialValue:
          facilities.any((f) => f.id == selectedId) ? selectedId : null,
      decoration: InputDecoration(
        labelText: 'Tesis Seçin',
        filled: true,
        fillColor: theme.surface,
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
            _selectedFacilityId = newId;
          });
        }
      },
    );
  }

  Widget _buildUnverifiedBanner(ProFeatureThemeData theme) {
    return Container(
      key: const Key('unverified-facility-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline_rounded, color: theme.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Doğrulanamıyor',
              style: TextStyle(
                color: theme.warning,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationCard(
    ProFeatureThemeData theme,
    FacilityReservation res,
  ) {
    final statusColor =
        res.status == 'confirmed' ? theme.success : theme.warning;
    final statusText = res.status == 'confirmed' ? 'Onaylı' : 'Bekliyor';

    return Container(
      key: Key('reservation-card-${res.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      res.title,
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: theme.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDate(res.startsAt)} ${_formatTime(res.startsAt)} - ${_formatTime(res.endsAt)}',
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.category_outlined, size: 16, color: theme.inkMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _kindLabel(res.kind),
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _kindLabel(String kind) {
    return switch (kind) {
      'rental' => 'Kiralama',
      'maintenance' => 'Bakım / Onarım',
      'private_lesson' => 'Özel Ders',
      'club_event' => 'Kulüp Etkinliği',
      _ => 'Diğer',
    };
  }
}
