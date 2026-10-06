import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

class MedicalCenterScreen extends ConsumerWidget {
  const MedicalCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final board = ref.watch(eligibilityBoardProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(eligibilityBoardProvider);
            await ref.read(eligibilityBoardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
            children: [
              SwanPageHeader(
                  title: 'Medikal & Sağlık Merkezi',
                  subtitle: 'Sporcu uygunluk durumu'),
              const SizedBox(height: SwanSpace.md),
              board.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (rows) => rows.isEmpty
                    ? premiumEmpty(context,
                        icon: Icons.health_and_safety_outlined,
                        title: 'Uygunluk kaydı yok',
                        subtitle:
                            'Kulübün erişilebilir uygunluk kayıtları burada gösterilir.')
                    : Column(children: [
                        for (final row in rows)
                          ListTile(
                            title: Text(row.athleteRef,
                                style: SwanType.body(c.ink)),
                            subtitle: Text(row.reasonLabel,
                                style: SwanType.bodySm(c.inkMuted)),
                            trailing: Text(
                                switch (row.status) {
                                  'restricted' => 'Kısıtlı',
                                  'awaiting_verification' => 'Onay bekliyor',
                                  'eligible' => 'Uygun',
                                  _ => 'Bilinmiyor',
                                },
                                style: SwanType.caption(
                                    row.isRestricted ? c.danger : c.inkMuted)),
                          )
                      ]),
              ),
            ],
          ),
        ),
      ))),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}
