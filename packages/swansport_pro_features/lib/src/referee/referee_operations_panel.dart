import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../club/club_operation_card.dart';
import '../federation/federation_operations_panel.dart';
import '../host/pro_feature_host.dart';

/// Shared referee operations panel embedded in `ProWorkspace.referee`
/// (Dashboard & Tasks) and usable by thin host shells.
///
/// Enforces:
/// - Access gate via `SwanAccess.isReferee`.
/// - Feature flag check for `FeatureFlags.refereeCockpit`.
/// - Never queries `refereeDutyMatchesProvider` for unauthorized accounts.
final class SharedRefereeOperationsPanel extends ConsumerWidget {
  const SharedRefereeOperationsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.isReferee) {
      return const FederationPanelMessage(
        icon: Icons.lock_person_outlined,
        title: 'Hakem operasyon yetkisi gerekli',
        body:
            'Bu çalışma alanı yalnız aktif hakem lisansı bulunan hesaplara açıktır.',
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    if (flagsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (flagsAsync.hasError) {
      return FederationPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(flagsAsync.error!).userMessage,
        onRetry: () => ref.invalidate(featureFlagsProvider),
      );
    }
    final enabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.refereeCockpit) ?? false;
    if (!enabled) {
      return const FederationPanelMessage(
        icon: Icons.toggle_off_outlined,
        title: 'Hakem kokpiti şu anda devre dışı',
        body: 'Hakem operasyon modülü özellik bayrağı kapalıdır.',
      );
    }

    final dutiesAsync = ref.watch(refereeDutyMatchesProvider);
    final profile = access.refereeProfile;

    return dutiesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => FederationPanelMessage(
        icon: Icons.error_outline_rounded,
        title: classifyOperationError(err).userMessage,
        onRetry: () => ref.invalidate(myRefereeMatchesProvider),
      ),
      data: (matches) {
        final now = DateTime.now();
        final pendingCount = matches
            .where(
              (m) =>
                  m.matchStatus == 'scheduled' &&
                  m.status == MatchOfficialStatus.assigned,
            )
            .length;
        final acceptedActive = matches
            .where(
              (m) =>
                  m.matchStatus == 'scheduled' &&
                  m.status == MatchOfficialStatus.accepted,
            )
            .toList(growable: false);
        final todayControllable = acceptedActive
            .where(
              (m) =>
                  m.canControl &&
                  refereeSupportsLive(m.sportCode) &&
                  refereeSameDay(m.startsAt, now),
            )
            .toList(growable: false);
        final firstMatch =
            todayControllable.firstOrNull ?? acceptedActive.firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hakem Operasyonları',
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Branş: ${profile.sportCode} · Lisans: ${profile.licenseNumber} · İl ${profile.cityCode}',
                      style: TextStyle(
                        color: theme.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClubOperationCard(
              icon: Icons.sports_outlined,
              title: 'Hakem Görevlerim & Yanıtlar',
              detail:
                  '${matches.length} toplam görev · $pendingCount onay bekleyen atama',
              onTap: host.navigator.openRefereeDuties,
              theme: theme,
            ),
            if (firstMatch != null) ...[
              const SizedBox(height: 10),
              ClubOperationCard(
                icon: Icons.fact_check_outlined,
                title: 'Dijital Esame Onayı',
                detail:
                    '${firstMatch.homeClubName ?? 'Ev Sahibi'} - ${firstMatch.awayClubName ?? 'Deplasman'}',
                onTap: () => host.navigator.openRefereeLineup(
                  firstMatch.matchId,
                ),
                theme: theme,
              ),
              if (refereeSupportsLive(firstMatch.sportCode)) ...[
                const SizedBox(height: 10),
                ClubOperationCard(
                  icon: Icons.timer_outlined,
                  title: 'Canlı Hakem Kokpiti',
                  detail:
                      '${firstMatch.sportCode.toUpperCase()} canlı skor, kart ve oyuncu değişikliği',
                  onTap: () => host.navigator.openRefereeLiveCockpit(
                    firstMatch.matchId,
                  ),
                  theme: theme,
                ),
              ],
              const SizedBox(height: 10),
              ClubOperationCard(
                icon: Icons.description_outlined,
                title: 'Resmî Maç Raporu',
                detail: 'Değişmez (immutable) maç sonu hakem raporu ve imza',
                onTap: () => host.navigator.openRefereeMatchReport(
                  firstMatch.matchId,
                ),
                theme: theme,
              ),
            ],
          ],
        );
      },
    );
  }
}

String sharedRefereeDutyLabel(MatchOfficialDuty duty) => switch (duty) {
      MatchOfficialDuty.headReferee => 'Başhakem',
      MatchOfficialDuty.assistantReferee1 => '1. Yardımcı Hakem',
      MatchOfficialDuty.assistantReferee2 => '2. Yardımcı Hakem',
      MatchOfficialDuty.fourthReferee => 'Dördüncü Hakem',
      MatchOfficialDuty.tableOfficial => 'Masa Hakemi',
      MatchOfficialDuty.observer => 'Gözlemci',
    };

String sharedRefereeStatusLabel(MatchOfficialStatus status) => switch (status) {
      MatchOfficialStatus.assigned => 'Yanıt bekliyor',
      MatchOfficialStatus.accepted => 'Kabul edildi',
      MatchOfficialStatus.declined => 'Mazeret bildirildi',
      MatchOfficialStatus.replaced => 'Görev değiştirildi',
    };

String sharedRefereeMatchStatusLabel(String status) => switch (status) {
      'scheduled' => 'Programda',
      'played' => 'Tamamlandı',
      'cancelled' => 'İptal',
      _ => 'Durum doğrulanmalı',
    };

String sharedRefereeTime(DateTime? instant) {
  if (instant == null) return 'Tarih belirtilmedi';
  final d = refereeTurkeyTime(instant);
  return '${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
