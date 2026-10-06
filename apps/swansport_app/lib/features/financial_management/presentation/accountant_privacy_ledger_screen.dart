import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Reads exclusively through acc_ledger; athlete names are never requested.
class AccountantPrivacyLedgerScreen extends ConsumerStatefulWidget {
  const AccountantPrivacyLedgerScreen({super.key});
  @override
  ConsumerState<AccountantPrivacyLedgerScreen> createState() => _LedgerState();
}

class _LedgerState extends ConsumerState<AccountantPrivacyLedgerScreen> {
  int _offset = 0;
  String? _clubId;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    if (_clubId != club?.id) {
      _clubId = club?.id;
      _offset = 0;
    }
    final page = ref.watch(clubLedgerPageProvider(_offset));
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(clubLedgerPageProvider);
            await ref.read(clubLedgerPageProvider(_offset).future);
          },
          child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
              children: [
                SwanPageHeader(
                    title: 'Muhasebeci defteri',
                    subtitle: club?.name ?? 'Kulüp seçilmedi'),
                const SizedBox(height: SwanSpace.md),
                Text('Sporcu kimlikleri sunucuda maskelenir.',
                    style: SwanType.bodySm(c.inkMuted)),
                const SizedBox(height: SwanSpace.md),
                page.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (data) => Column(children: [
                    if (data.entries.isEmpty)
                      Text('Defter kaydı bulunamadı.',
                          style: SwanType.bodySm(c.inkMuted)),
                    for (final row in data.entries)
                      ListTile(
                        title: Text(row.label, style: SwanType.body(c.ink)),
                        subtitle: Text(
                            '${row.counterpart} · ${row.movedOn.day}.${row.movedOn.month}.${row.movedOn.year} · ${row.status}'),
                        trailing: Text(
                            '${row.isIncome ? '+' : '-'}${money(row.amount)}',
                            style: SwanType.bodySm(c.ink)),
                      ),
                    const SizedBox(height: SwanSpace.md),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                              onPressed: _offset == 0
                                  ? null
                                  : () => setState(() => _offset =
                                      (_offset - 50).clamp(0, data.totalCount)),
                              child: const Text('Önceki')),
                          Text('${data.totalCount} kayıt',
                              style: SwanType.caption(c.inkMuted)),
                          TextButton(
                              onPressed: _offset + data.entries.length >=
                                      data.totalCount
                                  ? null
                                  : () => setState(() => _offset += 50),
                              child: const Text('Sonraki')),
                        ]),
                  ]),
                ),
              ]),
        ),
      ))),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}
