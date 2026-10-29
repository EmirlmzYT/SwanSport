import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import 'club_operation_card.dart';

final class SharedClubOperationsPanel extends ConsumerWidget {
  const SharedClubOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final clubAsync = ref.watch(activeClubProvider);
    final flagsAsync = ref.watch(featureFlagsProvider);
    if (clubAsync.isLoading || flagsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (clubAsync.hasError || flagsAsync.hasError) {
      final error = clubAsync.error ?? flagsAsync.error!;
      return _PanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(error).userMessage,
      );
    }

    final club = clubAsync.valueOrNull;
    if (club == null) {
      return const _PanelMessage(
        icon: Icons.shield_outlined,
        title: 'Aktif kulüp seçilmedi',
        body:
            'Kulüp operasyonlarını açmak için yetkili olduğun bir kulübü seç.',
      );
    }
    final access = ref.watch(swanAccessProvider);
    final membershipRole = club.role == 'club_admin' || club.role == 'coach';
    if (!access.hasActiveClubStaffMembership || !membershipRole) {
      return const _PanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Kulüp operasyon yetkisi gerekli',
        body:
            'Antrenör belgesi tek başına kulüp verilerini açmaz; aktif kulüp üyeliği gerekir.',
      );
    }

    final flags = flagsAsync.valueOrNull ?? const FeatureFlags.none();
    if (!flags.has(FeatureFlags.coachWorkspace)) {
      return const _PanelMessage(
        icon: Icons.lock_clock_outlined,
        title: 'Operasyonlar kademeli yayında',
        body: 'Kulüp ve antrenör operasyonları hesabın için henüz açılmadı.',
      );
    }

    final cards = <Widget>[];
    if (flags.has(FeatureFlags.teamHub)) {
      final teams = ref.watch(teamsProvider);
      final roster = ref.watch(clubRosterCountsProvider);
      cards
        ..add(
          ClubOperationCard(
            icon: Icons.groups_outlined,
            title: 'Takımlar',
            detail: _asyncDetail(
              teams,
              (items) => '${items.length} takım',
            ),
            onTap: host.navigator.openTeams,
            theme: host.theme,
          ),
        )
        ..add(
          ClubOperationCard(
            icon: Icons.badge_outlined,
            title: 'Sporcu Kadrosu',
            detail: _asyncDetail(
              roster,
              (value) => value == null
                  ? 'Kadro bilgisi yok'
                  : '${value.active} aktif / ${value.total} toplam',
            ),
            onTap: host.navigator.openTeams,
            theme: host.theme,
          ),
        );
    }
    if (flags.has(FeatureFlags.attendanceOperations)) {
      final today = ref.watch(clubTodayAttendanceProvider);
      final history = ref.watch(attendanceSummaryProvider);
      cards
        ..add(
          ClubOperationCard(
            icon: Icons.fact_check_outlined,
            title: 'Canlı Yoklama',
            detail: _asyncDetail(
              today,
              (value) => value == null
                  ? 'Bugün için veri yok'
                  : '${value.markedCount} / ${value.trainingCount} antrenmanda yoklama var',
            ),
            onTap: host.navigator.openAttendance,
            theme: host.theme,
          ),
        )
        ..add(
          ClubOperationCard(
            icon: Icons.analytics_outlined,
            title: 'Devam Geçmişi',
            detail: _asyncDetail(
              history,
              (items) => '${items.length} sporcu için devam kaydı',
            ),
            onTap: host.navigator.openAttendanceHistory,
            theme: host.theme,
          ),
        );
    }
    if (flags.has(FeatureFlags.sportTrainingSessions)) {
      final protocols = ref.watch(trainingProtocolsProvider);
      final live = ref.watch(myLiveSessionProvider);
      cards
        ..add(
          ClubOperationCard(
            icon: Icons.tune_outlined,
            title: 'Antrenman Şablonları',
            detail: _asyncDetail(
              protocols,
              (items) => '${items.length} kullanılabilir şablon',
            ),
            onTap: host.navigator.openTrainingProtocols,
            theme: host.theme,
          ),
        )
        ..add(
          ClubOperationCard(
            icon: Icons.sports_outlined,
            title: 'Antrenman Oturumu',
            detail: _asyncDetail(
              live,
              (value) => value == null || value.clubId != club.id
                  ? 'Aktif oturum yok'
                  : 'Canlı: ${value.protocolName}',
            ),
            onTap: () => host.navigator.openTrainingSession(
              sessionId: live.valueOrNull?.clubId == club.id
                  ? live.valueOrNull?.id
                  : null,
            ),
            theme: host.theme,
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kulüp Operasyonları',
          style: TextStyle(
            color: host.theme.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          club.name,
          style: TextStyle(color: host.theme.inkMuted),
        ),
        const SizedBox(height: 12),
        if (cards.isEmpty)
          const _PanelMessage(
            icon: Icons.hourglass_empty_rounded,
            title: 'Henüz açılmış bir operasyon modülü yok.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720 ? 2 : 1;
              final width = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final card in cards) SizedBox(width: width, child: card),
                ],
              );
            },
          ),
      ],
    );
  }
}

String _asyncDetail<T>(AsyncValue<T> value, String Function(T data) format) {
  return value.when(
    loading: () => 'Yükleniyor…',
    error: (error, _) => classifyOperationError(error).userMessage,
    data: format,
  );
}

final class _PanelMessage extends StatelessWidget {
  const _PanelMessage({required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = ProFeatureHostScope.of(context).theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: theme.inkMuted, size: 36),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.inkMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
