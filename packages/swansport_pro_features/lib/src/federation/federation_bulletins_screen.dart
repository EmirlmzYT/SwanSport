import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';
import '../host/pro_feature_state.dart';
import 'federation_operations_panel.dart';

/// Shared federation public bulletin and official notices screen for
/// SwanSport and SwanSport Pro.
///
/// Enforces:
/// - Access gate via `SwanAccess.canOpenFederationOperations`.
/// - Feature flag check for `FeatureFlags.federationBulletin`.
/// - Displays only published immutable public disciplinary summaries and
///   official federation notices.
/// - Never leaks private referee report notes, internal disciplinary reasons,
///   or free-text result revision reasons.
/// - Does not automatically unlock legacy `resultPublisher` write access.
final class SharedFederationBulletinsScreen extends ConsumerWidget {
  const SharedFederationBulletinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ProFeatureHostScope.of(context);
    final theme = host.theme;
    final access = ref.watch(swanAccessProvider);

    if (!access.canOpenFederationOperations) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: const FederationPanelMessage(
          icon: Icons.lock_person_outlined,
          title: 'Federasyon operasyon yetkisi gerekli',
          body:
              'Federasyon bülteni ve duyuru durumları için aktif federasyon görevi gereklidir.',
        ),
      );
    }

    final flagsAsync = ref.watch(featureFlagsProvider);
    final bulletinEnabled =
        flagsAsync.valueOrNull?.has(FeatureFlags.federationBulletin) ?? true;
    if (!bulletinEnabled) {
      return host.chrome.buildPage(
        context,
        title: 'Federasyon Bülten & Duyurular',
        body: const FederationPanelMessage(
          icon: Icons.toggle_off_outlined,
          title: 'Federasyon bülten modülü devre dışı',
          body: 'Bu özellik bayrağı şu anda etkin değil.',
        ),
      );
    }

    final scopesAsync = ref.watch(federationConsoleScopesProvider);
    final scopes = resolveEffectiveFederationScopes(
      scopesAsync.valueOrNull ?? const [],
      access,
    );
    final selectedKey = ref.watch(selectedFederationScopeKeyProvider);
    final selectedScope = scopes
            .where((item) => federationScopeKey(item) == selectedKey)
            .firstOrNull ??
        scopes.firstOrNull;

    final filter = (
      sportCode: selectedScope?.sportCode,
      cityCode: selectedScope?.cityCode,
      offset: 0,
      limit: 50,
    );
    final bulletinAsync = ref.watch(
      federationDisciplinaryBulletinProvider(filter),
    );
    final noticesAsync = ref.watch(federationNoticesProvider(filter));

    return host.chrome.buildPage(
      context,
      title: 'Federasyon Bülten & Duyurular',
      actions: [
        IconButton(
          tooltip: 'Yenile',
          onPressed: () {
            ref.invalidate(federationDisciplinaryBulletinProvider(filter));
            ref.invalidate(federationNoticesProvider(filter));
          },
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (scopes.length > 1 && selectedScope != null) ...[
            FederationScopeSelector(
              scopes: scopes,
              selectedScope: selectedScope,
              theme: theme,
            ),
            const SizedBox(height: 12),
          ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Kamusal Yayın & Bülten Durumu',
                      style: TextStyle(
                        color: theme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Chip(
                      label: Text(
                        access.canPublishFederationResults
                            ? 'Resmî Sonuç Yayın Yetkisi Aktif'
                            : 'Salt Okunur Bülten Görünümü',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Kamusal bültende yalnız açıkça yayımlanmış değişmez özetler (public_summary) ve resmî duyurular yer alır. İç disiplin gerekçeleri ve serbest sonuç revizyon notları kamuya sızdırılmaz. Federasyon rol etiketleri eski resultPublisher yetkisini otomatik açmaz.',
                  style: TextStyle(
                    color: theme.inkMuted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Yayımlanmış Disiplin Bülteni',
            style: TextStyle(
              color: theme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          bulletinAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(
                federationDisciplinaryBulletinProvider(filter),
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.line),
                  ),
                  child: Text(
                    'Bu kapsamda yayımlanmış kamusal disiplin bülteni kaydı bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in items) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${item.programName} · ${item.clubName}',
                                style: TextStyle(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Chip(label: Text(item.penaltyLabel)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sporcu Referansı: ${item.athleteDisplay} · ${item.matchTitle}',
                            style: TextStyle(
                              color: theme.inkMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.reason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              item.reason,
                              style: TextStyle(color: theme.ink, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Resmî Federasyon Duyuruları',
            style: TextStyle(
              color: theme.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          noticesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => FederationPanelMessage(
              icon: Icons.error_outline_rounded,
              title: classifyOperationError(err).userMessage,
              onRetry: () => ref.invalidate(federationNoticesProvider(filter)),
            ),
            data: (notices) {
              if (notices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.line),
                  ),
                  child: Text(
                    'Bu kapsamda yayımlanmış resmî federasyon duyurusu bulunmuyor.',
                    style: TextStyle(color: theme.inkMuted, fontSize: 12),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final notice in notices) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notice.title,
                            style: TextStyle(
                              color: theme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${notice.programName} · ${notice.sportCode}',
                            style: TextStyle(
                              color: theme.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notice.body,
                            style: TextStyle(color: theme.ink, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
