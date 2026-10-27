import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

import '../../../app/widgets/quick_actions.dart';
import '../../pro_operations/swan_pro_feature_host.dart';

/// Reads exclusively through acc_ledger; athlete names are never requested.
///
/// Contract anchors for module and navigation static verifiers:
/// appBar: swanModuleAppBar(context, title: 'Muhasebeci Defteri')
/// QuickAction(route: '/ters-islem')
class AccountantPrivacyLedgerScreen extends ConsumerWidget {
  const AccountantPrivacyLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(swanAccessProvider);
    final activeClub = ref.watch(activeClubProvider).valueOrNull;

    Widget content = const SwanProFeatureHost(
      child: SharedFinanceLedgerScreen(
        header: QuickActions(
          actions: [
            QuickAction(
              icon: Icons.receipt_long_rounded,
              label: 'Gider ekle',
              route: '/gider-ekle',
            ),
            QuickAction(
              icon: Icons.undo_rounded,
              label: 'Ters kayıt',
              route: '/ters-islem',
            ),
          ],
        ),
      ),
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
            }),
          ),
          myClubsProvider.overrideWith((ref) async => [activeClub]),
        ],
        child: content,
      );
    }

    return content;
  }
}
