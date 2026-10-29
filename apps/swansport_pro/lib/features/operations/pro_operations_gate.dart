import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../workspaces/pro_workspace_controller.dart';
import 'pro_club_context_selector.dart';
import 'pro_feature_host.dart';

class ProOperationsGate extends ConsumerWidget {
  const ProOperationsGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final clubsAsync = ref.watch(proAuthorizedClubsProvider);
    return clubsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text(classifyOperationError(error).userMessage)),
      ),
      data: (clubs) {
        if (clubs.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Bu çalışma alanında aktif kulüp operasyon yetkin bulunmuyor.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final selectedId = ref.watch(selectedClubIdProvider);
        final selected =
            clubs.where((item) => item.id == selectedId).firstOrNull;
        if (selected == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedClubIdProvider.notifier).state = clubs.first.id;
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final club = selected;
        final userId =
            ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
        return ProFeatureContextBoundary(
          contextKey: ProFeatureContextKey(
            userId: userId,
            workspace: workspace?.name ?? 'none',
            clubId: club.id,
          ),
          child: ProOperationsFeatureHost(child: child),
        );
      },
    );
  }
}

class ProFederationOperationsGate extends ConsumerWidget {
  const ProFederationOperationsGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    if (!access.canOpenFederationOperations) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu çalışma alanında aktif federasyon operasyon yetkin bulunmuyor.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final scopeKey = ref.watch(selectedFederationScopeKeyProvider);
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey(
        userId: userId,
        workspace: workspace?.name ?? 'federation',
        clubId: null,
        scopeId: scopeKey,
      ),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}

class ProRefereeOperationsGate extends ConsumerWidget {
  const ProRefereeOperationsGate({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    if (!access.isReferee) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Bu çalışma alanında aktif hakem operasyon yetkin bulunmuyor.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final workspace = ref.watch(selectedProWorkspaceProvider);
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey(
        userId: userId,
        workspace: workspace?.name ?? 'referee',
        clubId: null,
        scopeId: access.refereeProfile?.sportCode,
      ),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}

class ProAccountingOperationsGate extends ConsumerWidget {
  const ProAccountingOperationsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    final clubId = ref.watch(selectedAccountantClubIdProvider);
    if (!access.isAccountant ||
        clubId == null ||
        !access.accountantClubIds.contains(clubId)) {
      return const Scaffold(
        body: Center(child: Text('Aktif muhasebe kulüp kapsamı gerekli.')),
      );
    }
    if (ref.watch(selectedClubIdProvider) != clubId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedClubIdProvider.notifier).state = clubId;
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey.accounting(
        userId: userId,
        accountingClubId: clubId,
      ),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}

class ProFacilityOperationsGate extends ConsumerWidget {
  const ProFacilityOperationsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    final scopeId = ref.watch(selectedFacilityScopeIdProvider);
    final authorizedScopes = {
      ...access.managedTurfFieldIds,
      ...access.delegatedTurfFieldIds,
    };
    if (!access.canOpenTurfCenter ||
        scopeId == null ||
        !authorizedScopes.contains(scopeId)) {
      return const Scaffold(
        body: Center(child: Text('Aktif tesis operasyon kapsamı gerekli.')),
      );
    }
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey.facility(
        userId: userId,
        facilityScopeId: scopeId,
      ),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}

class ProPlatformOperationsGate extends ConsumerWidget {
  const ProPlatformOperationsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(swanAccessProvider).isPlatformAdmin) {
      return const Scaffold(
        body: Center(child: Text('Platform yöneticisi yetkisi gerekli.')),
      );
    }
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey.platform(userId: userId),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}

class ProClubSpecialistOperationsGate extends ConsumerWidget {
  const ProClubSpecialistOperationsGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    final clubId = ref.watch(selectedClubIdProvider);
    final allowed = clubId != null &&
        (access.canReadClubInventory(clubId) ||
            access.canReadClubHealth(clubId) ||
            access.canReadClubPlanning(clubId));
    if (!allowed) {
      return const Scaffold(
        body: Center(child: Text('Aktif kulüp ihtisas kapsamı gerekli.')),
      );
    }
    final userId = ref.watch(authSessionProvider).valueOrNull?.user.id ?? '';
    return ProFeatureContextBoundary(
      contextKey: ProFeatureContextKey(
        userId: userId,
        workspace: 'club-specialist',
        clubId: clubId,
      ),
      child: ProOperationsFeatureHost(child: child),
    );
  }
}
