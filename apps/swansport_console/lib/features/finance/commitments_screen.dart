import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'work_queue.dart';

/// Tedarikçiler ve tekrarlayan gider taahhütleri.
///
/// İki şey tek ekranda çünkü ayrılmaları anlamsız: taahhüdün neredeyse hepsi
/// bir tedarikçiye ait ve kullanıcı "kiraya kim bakıyor" ile "kira ne zaman"
/// sorularını aynı anda soruyor.
class CommitmentsScreen extends ConsumerWidget {
  const CommitmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final occurrences = ref.watch(upcomingOccurrencesProvider);
    final recurring = ref.watch(recurringExpensesProvider);
    final vendors = ref.watch(vendorsProvider);

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        ConsolePageHeader(
          title: 'Tedarikçi ve Taahhütler',
          subtitle: 'Kira, lisans, bakım gibi düzenli giderler ve vadeleri. '
              'Vade geldiğinde gider otomatik yazılmıyor — para çıktığını '
              'varsaymak defteri gerçekten ayırırdı.',
          trailing: FilledButton.icon(
            onPressed: () => _openRecurringDialog(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Taahhüt ekle'),
          ),
        ),
        const SizedBox(height: ConsoleDensity.xl),

        Text('Yaklaşan vadeler', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.sm),
        AsyncSection<List<RecurringOccurrence>>(
          value: occurrences,
          errorPrefix: 'Vadeler alınamadı',
          builder: (list) {
            if (list.isEmpty) {
              return Text('Önümüzdeki 30 günde vadesi gelen taahhüt yok.',
                  style: t.textTheme.bodySmall);
            }
            final now = DateTime.now();
            return Column(
              children: [for (final o in list) _OccurrenceRow(occ: o, now: now)],
            );
          },
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Text('Taahhütler', style: t.textTheme.titleMedium),
        const SizedBox(height: ConsoleDensity.sm),
        AsyncSection<List<RecurringExpense>>(
          value: recurring,
          errorPrefix: 'Taahhütler alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Henüz tekrarlayan gider tanımlanmadı.',
                  style: t.textTheme.bodySmall)
              : Column(children: [for (final r in list) _RecurringRow(rec: r)]),
        ),

        const SizedBox(height: ConsoleDensity.xxl),
        Row(
          children: [
            Expanded(
                child: Text('Tedarikçiler', style: t.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () => _openVendorDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tedarikçi ekle'),
            ),
          ],
        ),
        const SizedBox(height: ConsoleDensity.sm),
        Text(
          'Vergi numarası ve IBAN burada görünmez; ayrı bir kayıtta ve '
          'yalnızca kulüp yöneticisine açık.',
          style: t.textTheme.bodySmall,
        ),
        const SizedBox(height: ConsoleDensity.md),
        AsyncSection<List<Vendor>>(
          value: vendors,
          errorPrefix: 'Tedarikçiler alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Tedarikçi kaydı yok.', style: t.textTheme.bodySmall)
              : Wrap(
                  spacing: ConsoleDensity.sm,
                  runSpacing: ConsoleDensity.sm,
                  children: [
                    for (final v in list)
                      Chip(
                        label: Text(v.name),
                        avatar: const Icon(Icons.storefront_rounded, size: 16),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _OccurrenceRow extends ConsumerStatefulWidget {
  const _OccurrenceRow({required this.occ, required this.now});

  final RecurringOccurrence occ;
  final DateTime now;

  @override
  ConsumerState<_OccurrenceRow> createState() => _OccurrenceRowState();
}

class _OccurrenceRowState extends ConsumerState<_OccurrenceRow> {
  bool _busy = false;

  Future<void> _record() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(financeOpsServiceProvider)
          .recordOccurrence(widget.occ.id);
      ref.invalidate(upcomingOccurrencesProvider);
      ref.invalidate(financeOperationsSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gider kaydedildi')));
      }
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
    final o = widget.occ;
    final days = o.daysLeft(widget.now);
    final overdue = o.isOverdue(widget.now);

    // Renk tek başına bilgi taşımıyor: metin de durumu söylüyor.
    final label = overdue
        ? '${-days} gün gecikti'
        : days == 0
            ? 'Vadesi bugün'
            : '$days gün kaldı';

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(
            color: overdue
                ? t.colorScheme.error.withValues(alpha: 0.4)
                : t.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.title ?? 'Taahhüt', style: t.textTheme.titleSmall),
                Text('${fmtDate(o.dueOn)} · $label',
                    style: t.textTheme.bodySmall?.copyWith(
                        color: overdue ? t.colorScheme.error : null)),
              ],
            ),
          ),
          Text(fmtMoney(o.amount), style: t.textTheme.titleSmall),
          const SizedBox(width: ConsoleDensity.lg),
          if (_busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            FilledButton.tonal(
              onPressed: _record,
              child: const Text('Ödendi olarak işle'),
            ),
        ],
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  const _RecurringRow({required this.rec});

  final RecurringExpense rec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      padding: const EdgeInsets.all(ConsoleDensity.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(color: t.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(rec.title, style: t.textTheme.titleSmall),
                  if (!rec.active) ...[
                    const SizedBox(width: ConsoleDensity.sm),
                    Text('durduruldu',
                        style: t.textTheme.labelSmall
                            ?.copyWith(color: t.colorScheme.outline)),
                  ],
                ]),
                Text(
                  [
                    freqLabel(rec.frequency),
                    if (rec.vendorName != null) rec.vendorName!,
                    'ilk vade ${fmtDate(rec.startsOn)}',
                  ].join(' · '),
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(fmtMoney(rec.amount), style: t.textTheme.titleSmall),
          if (rec.active) ...[
            const SizedBox(width: ConsoleDensity.sm),
            IconButton(
              tooltip: 'Taahhüdü durdur (geçmiş kayıtlar silinmez)',
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Taahhüdü durdur'),
                    content: Text(
                        '${rec.title} için yeni vade üretilmeyecek. '
                        'Geçmiş giderler ve kayıtlar olduğu gibi kalır.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Durdur')),
                    ],
                  ),
                );
                if (ok != true) return;
                try {
                  await ref
                      .read(financeOpsServiceProvider)
                      .cancelRecurringExpense(rec.id);
                  ref.invalidate(recurringExpensesProvider);
                  ref.invalidate(upcomingOccurrencesProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- diyaloglar

Future<void> _openVendorDialog(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final note = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Tedarikçi ekle'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            const SizedBox(height: ConsoleDensity.md),
            TextField(
              controller: note,
              decoration: const InputDecoration(
                labelText: 'İletişim notu',
                hintText: 'Ahmet Bey · 0532 ...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet')),
      ],
    ),
  );

  if (ok != true || name.text.trim().isEmpty) return;
  final club = await ref.read(activeClubProvider.future);
  if (club == null) return;

  try {
    await ref.read(financeOpsServiceProvider).saveVendor(
          clubId: club.id,
          name: name.text.trim(),
          contactNote: note.text.trim().isEmpty ? null : note.text.trim(),
        );
    ref.invalidate(vendorsProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

Future<void> _openRecurringDialog(BuildContext context, WidgetRef ref) async {
  final title = TextEditingController();
  final amount = TextEditingController();
  var freq = 'monthly';
  var startsOn = DateTime.now();

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Taahhüt ekle'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Başlık', hintText: 'Salon kirası'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tutar'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              DropdownButtonFormField<String>(
                initialValue: freq,
                decoration: const InputDecoration(labelText: 'Sıklık'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('Aylık')),
                  DropdownMenuItem(
                      value: 'quarterly', child: Text('Üç aylık')),
                  DropdownMenuItem(value: 'yearly', child: Text('Yıllık')),
                ],
                onChanged: (v) => setState(() => freq = v ?? 'monthly'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              // İlk vade sonraki bütün vadeleri belirliyor; ayrı bir "ayın
              // kaçı" alanı yok, iki yerde gün tutmak ayrışma demekti.
              Row(children: [
                Expanded(child: Text('İlk vade: ${fmtDate(startsOn)}')),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startsOn,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => startsOn = picked);
                  },
                  child: const Text('Değiştir'),
                ),
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet')),
        ],
      ),
    ),
  );

  if (ok != true) return;
  final value = num.tryParse(amount.text.replaceAll(',', '.'));
  if (title.text.trim().isEmpty || value == null || value <= 0) return;

  final club = await ref.read(activeClubProvider.future);
  if (club == null) return;

  try {
    await ref.read(financeOpsServiceProvider).saveRecurringExpense({
      'club_id': club.id,
      'title': title.text.trim(),
      'amount': value,
      'frequency': freq,
      'starts_on': '${startsOn.year.toString().padLeft(4, '0')}-'
          '${startsOn.month.toString().padLeft(2, '0')}-'
          '${startsOn.day.toString().padLeft(2, '0')}',
    });
    ref.invalidate(recurringExpensesProvider);
    ref.invalidate(upcomingOccurrencesProvider);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
