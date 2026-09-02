import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Mali dönem kapanışı.
///
/// Kapanış bir bayrak değil, bir kilit: kapanmış dönemde gider, ödeme ve
/// bağış değişikliği veritabanı tetikleyicisiyle reddediliyor. Bu ekrandaki
/// düğmeleri gizlemek koruma değil — REST üzerinden doğrudan `update` yine
/// geçerdi.
///
/// Engel varsa dönem kapanmıyor ve **hangi maddenin engellediği** söyleniyor.
/// Düğmeyi pasif yapıp sebebi söylememek kullanıcıyı sistemle güreştirir.
class PeriodCloseScreen extends ConsumerStatefulWidget {
  const PeriodCloseScreen({super.key});

  @override
  ConsumerState<PeriodCloseScreen> createState() => _PeriodCloseScreenState();
}

class _PeriodCloseScreenState extends ConsumerState<PeriodCloseScreen> {
  FinancePeriod? _selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final periods = ref.watch(financePeriodsProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        ConsolePageHeader(
          title: 'Dönem Kapanışı',
          subtitle: 'Kapanan dönemde geçmiş kayıt değiştirilemez. Düzeltme '
              'için geçmişe dokunulmaz; bugüne ters kayıt yazılır.',
          trailing: FilledButton.icon(
            onPressed: () => _createPeriod(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Dönem aç'),
          ),
        ),
        const SizedBox(height: ConsoleDensity.xl),
        AsyncSection<List<FinancePeriod>>(
          value: periods,
          errorPrefix: 'Dönemler alınamadı',
          builder: (list) {
            if (list.isEmpty) {
              return Text(
                'Henüz mali dönem tanımlanmadı. Kapanış yapabilmek için önce '
                'bir dönem açman gerekiyor (genelde takvim ayı).',
                style: t.textTheme.bodySmall,
              );
            }
            final current = _selected ??
                list.firstWhere((p) => !p.isClosed, orElse: () => list.first);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: ConsoleDensity.sm,
                  runSpacing: ConsoleDensity.sm,
                  children: [
                    for (final p in list)
                      ChoiceChip(
                        selected: p.id == current.id,
                        onSelected: (_) => setState(() => _selected = p),
                        label: Text(
                            '${fmtDate(p.periodFrom)} – ${fmtDate(p.periodTo)}'
                            ' · ${p.statusLabel}'),
                      ),
                  ],
                ),
                const SizedBox(height: ConsoleDensity.xl),
                _Checklist(period: current),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _createPeriod(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    // Geçen ay: kapanış genelde bitmiş bir dönem için yapılır.
    final from = DateTime(now.year, now.month - 1, 1);
    final to = DateTime(now.year, now.month, 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mali dönem aç'),
        content: Text('${fmtDate(from)} – ${fmtDate(to)} dönemi açılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aç')),
        ],
      ),
    );
    if (ok != true) return;

    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;
    try {
      await ref
          .read(financeOpsServiceProvider)
          .createPeriod(club.id, from, to);
      ref.invalidate(financePeriodsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _Checklist extends ConsumerStatefulWidget {
  const _Checklist({required this.period});

  final FinancePeriod period;

  @override
  ConsumerState<_Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends ConsumerState<_Checklist> {
  late Future<List<CloseCheckItem>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Checklist old) {
    super.didUpdateWidget(old);
    if (old.period.id != widget.period.id) _load();
  }

  void _load() {
    _future = ref.read(financeOpsServiceProvider).closeChecklist(
        widget.period.clubId,
        widget.period.periodFrom,
        widget.period.periodTo);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return FutureBuilder<List<CloseCheckItem>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(ConsoleDensity.xl),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snap.hasError) {
          return Text('Kontrol listesi alınamadı: ${snap.error}',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.error));
        }

        final items = snap.data ?? const <CloseCheckItem>[];
        final blockers = items.where((i) => i.isBlocker).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kapanış kontrol listesi', style: t.textTheme.titleMedium),
            const SizedBox(height: ConsoleDensity.sm),
            for (final i in items)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i.qty == 0
                      ? Icons.check_circle_outline_rounded
                      : i.blocking
                          ? Icons.block_rounded
                          : Icons.info_outline_rounded,
                  size: 20,
                  color: i.qty == 0
                      ? t.colorScheme.primary
                      : i.blocking
                          ? t.colorScheme.error
                          : t.colorScheme.outline,
                ),
                title: Text(i.label),
                subtitle: Text(
                  i.qty == 0
                      ? 'Temiz'
                      : '${i.qty} kayıt'
                          '${i.amount != 0 ? ' · ${fmtMoney(i.amount)}' : ''}'
                          '${i.blocking ? ' · kapanışı engelliyor' : ' · bilgi'}',
                ),
              ),
            const SizedBox(height: ConsoleDensity.lg),
            if (widget.period.isClosed)
              Row(children: [
                Expanded(
                  child: Text(
                    'Bu dönem kapalı. Değişiklik gerekiyorsa düzeltme kaydı '
                    'aç ya da gerekçeyle geri aç.',
                    style: t.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _reopen,
                  child: const Text('Geri aç'),
                ),
              ])
            else if (blockers.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ConsoleDensity.lg),
                decoration: BoxDecoration(
                  color: t.colorScheme.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(ConsoleDensity.radius),
                  border: Border.all(
                      color: t.colorScheme.error.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kapanış engellendi',
                        style: t.textTheme.titleSmall
                            ?.copyWith(color: t.colorScheme.error)),
                    const SizedBox(height: ConsoleDensity.xs),
                    Text(
                      blockers
                          .map((b) => '${b.label} (${b.qty})')
                          .join(', '),
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              FilledButton(
                onPressed: _busy ? null : _close,
                child: const Text('Dönemi kapat'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _close() async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(
        title: 'Dönemi kapat',
        hint: 'Kapanış notu (isteğe bağlı)',
        confirm: 'Kapat',
        required: false,
      ),
    );
    if (note == null) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .closePeriod(widget.period.id, note: note.isEmpty ? null : note);
      ref.invalidate(financePeriodsProvider);
      ref.invalidate(financeOperationsSummaryProvider);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reopen() async {
    // Gerekçe zorunlu — sunucu da zorunlu tutuyor. Kapanışı geri almak
    // olağan bir işlem değil; kolaylaştırmak kapanışın anlamını yok eder.
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(
        title: 'Dönemi geri aç',
        hint: 'Gerekçe (zorunlu)',
        confirm: 'Geri aç',
        required: true,
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .reopenPeriod(widget.period.id, reason);
      ref.invalidate(financePeriodsProvider);
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.title,
    required this.hint,
    required this.confirm,
    required this.required,
  });

  final String title;
  final String hint;
  final String confirm;
  final bool required;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocked = widget.required && _c.text.trim().isEmpty;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: TextField(
          controller: _c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(labelText: widget.hint),
          onChanged: (_) => setState(() {}),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç')),
        FilledButton(
          onPressed:
              blocked ? null : () => Navigator.pop(context, _c.text.trim()),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
