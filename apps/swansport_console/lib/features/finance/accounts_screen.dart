import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';
import 'money.dart';

/// Kasa, banka ve POS hesapları.
///
/// Bakiyeler veritabanında saklanmıyor, hareketlerden hesaplanıyor. Saklansaydı
/// iptal edilen bir ödeme ya da düzeltilen bir gider sonrası gerçekle ayrışır
/// ve kimse hangisinin doğru olduğunu bilemezdi.
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final balances = ref.watch(accountBalancesProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: ConsoleDensity.lg, vertical: ConsoleDensity.sm),
          child: Row(
            children: [
              Text('Hesaplar', style: t.textTheme.titleMedium),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _addAccount(context, ref),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Hesap ekle'),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: balances.when(
            loading: () =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(ConsoleDensity.xxl),
                child: SelectableText('Bakiyeler alınamadı: $e',
                    textAlign: TextAlign.center,
                    style: t.textTheme.bodySmall),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      'Henüz hesap tanımlı değil.\n\n'
                      'Kasa, banka ve POS hesaplarını tanımlarsan her gelir ve '
                      'gider bir hesaba işlenir; "bankada ne var, kasada ne var" '
                      'sorusu cevaplanır.',
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                );
              }

              final total = list.fold<num>(0, (a, b) => a + b.balance);

              return ListView(
                padding: const EdgeInsets.all(ConsoleDensity.xl),
                children: [
                  Wrap(
                    spacing: ConsoleDensity.lg,
                    runSpacing: ConsoleDensity.lg,
                    children: [for (final b in list) _AccountCard(balance: b)],
                  ),
                  const SizedBox(height: ConsoleDensity.xxl),
                  Divider(color: t.colorScheme.outline),
                  const SizedBox(height: ConsoleDensity.lg),
                  Row(
                    children: [
                      Text('TOPLAM', style: t.textTheme.labelSmall),
                      const Spacer(),
                      Text(
                        fmtMoney(total),
                        style: t.textTheme.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: total < 0 ? t.colorScheme.error : null,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addAccount(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    var kind = 'bank';

    // Diyalogdan sonra context'e dokunmamak icin simdi aliniyor.
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Hesap ekle'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Ad', hintText: 'Nakit kasa, Ziraat…'),
                ),
                const SizedBox(height: ConsoleDensity.md),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'Tür'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Nakit kasa')),
                    DropdownMenuItem(value: 'bank', child: Text('Banka')),
                    DropdownMenuItem(value: 'pos', child: Text('POS')),
                  ],
                  onChanged: (v) => setState(() => kind = v ?? 'bank'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ekle')),
          ],
        ),
      ),
    );

    if (ok != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) return;
      await ref
          .read(expenseServiceProvider)
          .addAccount(club.id, nameCtrl.text.trim(), kind);
      ref
        ..invalidate(cashAccountsProvider)
        ..invalidate(accountBalancesProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Eklenemedi: $e')));
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.balance});

  final AccountBalance balance;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final negative = balance.balance < 0;

    return Container(
      width: 260,
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        border: Border.all(
            color: negative
                ? t.colorScheme.error.withValues(alpha: .35)
                : t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        color: negative ? t.colorScheme.error.withValues(alpha: .05) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(balance.name,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              StatusPill(
                label: switch (balance.kind) {
                  'cash' => 'Kasa',
                  'pos' => 'POS',
                  _ => 'Banka',
                },
                tone: PillTone.info,
              ),
            ],
          ),
          const SizedBox(height: ConsoleDensity.md),
          Text(
            fmtMoney(balance.balance),
            style: t.textTheme.titleLarge?.copyWith(
              fontSize: 24,
              color: negative ? t.colorScheme.error : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: ConsoleDensity.sm),
          Row(
            children: [
              Text('+${fmtMoney(balance.income)}',
                  style: t.textTheme.bodySmall),
              const SizedBox(width: ConsoleDensity.md),
              Text('−${fmtMoney(balance.outgo)}',
                  style: t.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
