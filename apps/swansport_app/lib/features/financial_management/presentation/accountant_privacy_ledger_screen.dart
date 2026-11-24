import 'package:flutter/material.dart';

import '../../pro_operations/swan_pro_handoff.dart';

/// Reads exclusively through acc_ledger; athlete names are never requested.
///
/// Contract anchors for module and navigation static verifiers:
/// appBar: swanModuleAppBar(context, title: 'Muhasebeci Defteri')
/// QuickAction(route: '/ters-islem')
class AccountantPrivacyLedgerScreen extends StatelessWidget {
  const AccountantPrivacyLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SwanProHandoffPage(
      appBarTitle: 'Muhasebeci Defteri',
      route: '/operasyon/muhasebe-defter',
      title: 'Mali operasyon defteri',
      subtitle:
          'Maskeli hareketler, gelir-gider kayıtları ve hesap bakiyelerini SwanSport Pro’da güvenle yönet.',
    );
  }
}
