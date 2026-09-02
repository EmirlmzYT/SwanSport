import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Banka mutabakatı.
///
/// **Öneri asla defter kaydı üretmez.** Sistem eşleşme önerir, insan kabul
/// eder. Otomatik eşleştirme, yanlış eşleşmeyi denetim izinde "muhasebeci
/// onayladı" gibi gösterirdi.
///
/// Ekstredeki açıklama sunucuda maskelenmiş geliyor: IBAN ve uzun rakam
/// dizileri gizli, ham metin bu ekrana hiç ulaşmıyor ve dışa aktarıma
/// girmiyor.
class ReconciliationScreen extends ConsumerStatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  ConsumerState<ReconciliationScreen> createState() =>
      _ReconciliationScreenState();
}

class _ReconciliationScreenState
    extends ConsumerState<ReconciliationScreen> {
  String _status = 'unmatched';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final txns = ref.watch(bankTransactionsProvider(_status));
    final imports = ref.watch(bankImportsProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        ConsolePageHeader(
          title: 'Banka Mutabakatı',
          subtitle: 'Ekstre satırlarını defter kayıtlarıyla eşleştir. Sistem '
              'yalnızca öneri verir; kaydı sen onaylarsın.',
          trailing: OutlinedButton.icon(
            onPressed: () => _showTemplate(context),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('CSV şablonu'),
          ),
        ),
        const SizedBox(height: ConsoleDensity.xl),

        AsyncSection<List<BankImport>>(
          value: imports,
          errorPrefix: 'Yüklemeler alınamadı',
          builder: (list) => list.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(ConsoleDensity.lg),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(ConsoleDensity.radius),
                    border:
                        Border.all(color: t.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Henüz ekstre yüklenmedi',
                          style: t.textTheme.titleSmall),
                      const SizedBox(height: ConsoleDensity.xs),
                      Text(
                        'Bankadan indirdiğin hareket dökümünü CSV şablonuna '
                        'çevirip yükle. Aynı dosya ikinci kez yüklenemez — '
                        'içerik özeti kontrol ediliyor.',
                        style: t.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final i in list.take(3))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.upload_file_rounded,
                            size: 20),
                        title: Text(
                            '${i.accountName ?? 'Hesap'} · ${i.rowCount} satır'),
                        subtitle: Text(i.periodFrom == null
                            ? fmtDate(i.createdAt)
                            : '${fmtDate(i.periodFrom!)} – '
                                '${fmtDate(i.periodTo ?? i.periodFrom!)}'),
                      ),
                  ],
                ),
        ),

        const SizedBox(height: ConsoleDensity.xl),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'unmatched', label: Text('Eşleşmemiş')),
            ButtonSegment(value: 'matched', label: Text('Eşleşmiş')),
            ButtonSegment(value: 'all', label: Text('Tümü')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
        const SizedBox(height: ConsoleDensity.lg),

        AsyncSection<List<BankTransaction>>(
          value: txns,
          errorPrefix: 'Hareketler alınamadı',
          builder: (list) => list.isEmpty
              ? Text(
                  _status == 'unmatched'
                      ? 'Eşleşmemiş hareket yok. Mutabakat temiz.'
                      : 'Bu süzgeçte hareket yok.',
                  style: t.textTheme.bodySmall)
              : Column(children: [for (final x in list) _TxnRow(txn: x)]),
        ),
      ],
    );
  }

  void _showTemplate(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV şablonu'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sütun sırası sabit, ilk satır başlık. Ayraç noktalı virgül '
                '(Türkçe Excel varsayılanı), ondalık virgül.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: ConsoleDensity.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ConsoleDensity.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                ),
                child: const SelectableText(
                  'tarih;aciklama;tutar;yon\n'
                  '2026-09-01;EFT - AHMET Y.;1500,00;giris\n'
                  '2026-09-02;KIRA ODEMESI;12000,00;cikis',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Text(
                'İlk sürümde banka API bağlantısı ve e-fatura yok. Her '
                'bankanın kendi biçimini desteklemek, mutabakatın kendisinden '
                'büyük bir iş ve hiçbiri doğrulanmadan yazılamaz.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat')),
        ],
      ),
    );
  }
}

class _TxnRow extends ConsumerStatefulWidget {
  const _TxnRow({required this.txn});

  final BankTransaction txn;

  @override
  ConsumerState<_TxnRow> createState() => _TxnRowState();
}

class _TxnRowState extends ConsumerState<_TxnRow> {
  bool _open = false;
  bool _busy = false;

  Future<void> _decide(String action, {String? kind, String? id}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .decideMatch(widget.txn.id, action, kind: kind, entryId: id);
      ref.invalidate(bankTransactionsProvider);
      ref.invalidate(financeOperationsSummaryProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final x = widget.txn;

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(children: [
            // Yön hem ikon hem metinle: renk tek başına bilgi taşımıyor.
            Icon(
                x.isIncoming
                    ? Icons.south_west_rounded
                    : Icons.north_east_rounded,
                size: 18,
                color: x.isIncoming
                    ? t.colorScheme.primary
                    : t.colorScheme.onSurfaceVariant),
            const SizedBox(width: ConsoleDensity.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(x.description ?? '(açıklama yok)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodyMedium),
                  Text(
                      '${fmtDate(x.txnOn)} · '
                      '${x.isIncoming ? 'giriş' : 'çıkış'}'
                      '${x.isMatched ? ' · eşleşti' : ''}',
                      style: t.textTheme.bodySmall),
                ],
              ),
            ),
            Text(fmtMoney(x.amount), style: t.textTheme.titleSmall),
            const SizedBox(width: ConsoleDensity.md),
            if (_busy)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else if (x.isMatched)
              TextButton(
                onPressed: () => _decide('unmatch'),
                child: const Text('Eşleşmeyi kaldır'),
              )
            else ...[
              TextButton(
                onPressed: () => _decide('ignore'),
                child: const Text('Yoksay'),
              ),
              const SizedBox(width: ConsoleDensity.sm),
              FilledButton.tonal(
                onPressed: () => setState(() => _open = !_open),
                child: Text(_open ? 'Kapat' : 'Eşleştir'),
              ),
            ],
          ]),
          if (_open) ...[
            const Divider(height: ConsoleDensity.xl),
            _Suggestions(
              txnId: x.id,
              onPick: (kind, id) =>
                  _decide('match', kind: kind, id: id).then((_) {
                if (mounted) setState(() => _open = false);
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _Suggestions extends ConsumerWidget {
  const _Suggestions({required this.txnId, required this.onPick});

  final String txnId;
  final void Function(String kind, String id) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return AsyncSection<List<BankMatchSuggestion>>(
      value: ref.watch(bankMatchSuggestionsProvider(txnId)),
      errorPrefix: 'Öneri alınamadı',
      builder: (list) {
        if (list.isEmpty) {
          return Text(
            'Tutarı ve yönü tutan, ±5 gün içinde bir defter kaydı yok. '
            'Kayıt eksikse önce onu deftere gir — mutabakat ekranı gider '
            'yazma yeri değil.',
            style: t.textTheme.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Öneriler', style: t.textTheme.labelMedium),
            const SizedBox(height: ConsoleDensity.sm),
            for (final s in list)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${s.label} · ${fmtMoney(s.amount)}'),
                subtitle: Text(
                    '${fmtDate(s.entryOn)} · '
                    '${s.dayGap == 0 ? 'aynı gün' : '${s.dayGap} gün fark'}'),
                trailing: TextButton(
                  onPressed: () => onPick(s.kind, s.entryId),
                  child: const Text('Bu'),
                ),
              ),
          ],
        );
      },
    );
  }
}
