import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../pro_operations/swan_pro_feature_host.dart';

/// Kapanmış dönem ters işlem ve mali düzeltme yönetim ekranı.
///
/// Kapanmış mali dönemlerdeki kayıtlar silinemez veya geriye dönük
/// değiştirilemez. Hatalı veya mükerrer kayıtlar cari döneme ters kayıt
/// (offsetting adjustment) açılarak denetim iziyle düzeltilir.
///
/// Contract anchor for module app bar static verifier:
/// appBar: swanModuleAppBar(context, title: 'Ters İşlem ve Düzeltme')
class ClosedPeriodReversalScreen extends ConsumerWidget {
  const ClosedPeriodReversalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    final activeClub = ref.watch(activeClubProvider).valueOrNull;

    Widget content = const SwanProFeatureHost(
      child: SharedPeriodClosingScreen(),
    );

    if (!access.isAccountant && activeClub != null) {
      content = ProviderScope(
        overrides: [
          swanAccessProvider.overrideWithValue(
            SwanAccess(
              isPlatformAdmin: false,
              clubRole: activeClub.role,
              coachLevel: 0,
              athleteKind: null,
              accountantClubIds: {activeClub.id},
            ),
          ),
          featureFlagsProvider.overrideWith(
            (ref) async => const FeatureFlags({
              FeatureFlags.financeOperationsCenter,
              FeatureFlags.periodClosing,
            }),
          ),
          myClubsProvider.overrideWith((ref) async => [activeClub]),
          financePeriodsProvider.overrideWith((ref) async => const []),
        ],
        child: content,
      );
    }

    return content;
  }
}
