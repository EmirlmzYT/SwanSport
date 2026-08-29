import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'ledger_providers.dart';

/// Gider ekleme / düzenleme penceresi.
///
/// [existing] verilirse düzenleme; mobilden gelen taslak giderler böyle
/// tamamlanıyor.
Future<void> showExpenseDialog(
  BuildContext context,
  WidgetRef ref, {
  ExpenseRow? existing,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _ExpenseDialog(existing: existing),
  );
}

class _ExpenseDialog extends ConsumerStatefulWidget {
  const _ExpenseDialog({this.existing});

  final ExpenseRow? existing;

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  late final TextEditingController _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.amount.toStringAsFixed(2).replaceAll('.', ','));
  late final TextEditingController _supplier =
      TextEditingController(text: widget.existing?.supplier ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');

  late DateTime _date = widget.existing?.spentOn ?? DateTime.now();
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;

  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _amount.dispose();
    _supplier.dispose();
    _note.dispose();
    super.dispose();
  }

  /// "1.234,56" ve "1234.56" ikisini de kabul eder.
  ///
  /// Türkçe klavyeden virgül, kopyala-yapıştırdan nokta gelebiliyor; kullanıcıyı
  /// biçime zorlamak yerine ikisini de anlıyoruz.
  num? _parseAmount(String raw) {
    var s = raw.trim().replaceAll(' ', '').replaceAll('₺', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    }
    final v = num.tryParse(s);
    return (v == null || v <= 0) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final categories = ref.watch(expenseCategoriesProvider);
    final accounts = ref.watch(cashAccountsProvider);
    final suggestions =
        ref.watch(supplierSuggestionsProvider).valueOrNull ?? const <String>[];

    return AlertDialog(
      title: Text(_isEdit ? 'Gideri düzenle' : 'Gider ekle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fiş görseli — mobilden yüklenmişse burada açılıyor. Fişi
              // çekmenin amacı sonradan bakılabilmesiydi; görünmezse o adım
              // boşa gidiyordu.
              if (_isEdit && widget.existing!.receiptPath != null) ...[
                _ReceiptPreview(path: widget.existing!.receiptPath!),
                const SizedBox(height: ConsoleDensity.lg),
              ],
              if (_isEdit && widget.existing!.isDraft)
                Padding(
                  padding: const EdgeInsets.only(bottom: ConsoleDensity.md),
                  child: Text(
                    'Bu kayıt mobilden fişle girilmiş bir taslak. Kaydedince '
                    'tamamlanmış sayılır ve raporlara girer.',
                    style: t.textTheme.bodySmall,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Tutar',
                        suffixText: '₺',
                      ),
                    ),
                  ),
                  const SizedBox(width: ConsoleDensity.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius:
                          BorderRadius.circular(ConsoleDensity.radius),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Tarih'),
                        child: Text(fmtDate(_date)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ConsoleDensity.md),
              categories.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('Kategoriler alınamadı: $e',
                    style: t.textTheme.bodySmall),
                data: (list) => DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Seçilmedi')),
                    for (final c in list)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              accounts.when(
                loading: () => const LinearProgressIndicator(minHeight: 2),
                error: (e, _) => Text('Hesaplar alınamadı: $e',
                    style: t.textTheme.bodySmall),
                data: (list) => list.isEmpty
                    ? Text(
                        'Kasa/banka hesabı tanımlı değil. Hesap eklemeden de '
                        'gider girebilirsin ama bakiye takibi yapılamaz.',
                        style: t.textTheme.bodySmall)
                    : DropdownButtonFormField<String?>(
                        initialValue: _accountId,
                        decoration:
                            const InputDecoration(labelText: 'Hangi hesaptan'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Belirtilmedi')),
                          for (final a in list)
                            DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.name} · ${a.kindLabel}')),
                        ],
                        onChanged: (v) => setState(() => _accountId = v),
                      ),
              ),
              const SizedBox(height: ConsoleDensity.md),
              // Tedarikçi ayrı tablo değil; öneri listesi yazım farklarını
              // ("Migros" / "migros") azaltmak için.
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _supplier.text),
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return suggestions
                      .where((s) => s.toLowerCase().contains(q))
                      .take(6);
                },
                onSelected: (s) => _supplier.text = s,
                fieldViewBuilder: (context, controller, focus, onSubmit) {
                  controller.addListener(() => _supplier.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    decoration:
                        const InputDecoration(labelText: 'Kime ödendi'),
                  );
                },
              ),
              const SizedBox(height: ConsoleDensity.md),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Açıklama'),
              ),
              if (_error != null) ...[
                const SizedBox(height: ConsoleDensity.md),
                Text(_error!,
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEdit)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Sil'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = _parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Geçerli bir tutar gir (örn. 1.250,00)');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) throw StateError('Aktif kulüp yok');
      final svc = ref.read(expenseServiceProvider);

      if (_isEdit) {
        await svc.updateExpense(
          widget.existing!.id,
          amount: amount,
          spentOn: _date,
          categoryId: _categoryId,
          accountId: _accountId,
          supplier: _supplier.text.trim(),
          note: _note.text.trim(),
          // Taslak düzenlenince tamamlanmış sayılır.
          status: 'complete',
        );
      } else {
        await svc.addExpense(
          clubId: club.id,
          amount: amount,
          spentOn: _date,
          categoryId: _categoryId,
          accountId: _accountId,
          supplier: _supplier.text.trim(),
          note: _note.text.trim(),
        );
      }

      _refresh();
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    try {
      await ref.read(expenseServiceProvider).deleteExpense(widget.existing!.id);
      _refresh();
      navigator.pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  void _refresh() {
    ref
      ..invalidate(ledgerProvider)
      ..invalidate(draftExpensesProvider)
      ..invalidate(categoryBreakdownProvider)
      ..invalidate(accountBalancesProvider)
      ..invalidate(supplierSuggestionsProvider);
  }
}


/// Gidere bağlı fiş/fatura görseli.
class _ReceiptPreview extends ConsumerWidget {
  const _ReceiptPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final url = ref.watch(receiptUrlProvider(path));

    return url.when(
      loading: () => const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(ConsoleDensity.md),
        decoration: BoxDecoration(
          border: Border.all(color: t.colorScheme.outline),
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        ),
        child: Text('Fiş açılamadı: $e', style: t.textTheme.bodySmall),
      ),
      data: (link) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FİŞ', style: t.textTheme.labelSmall),
          const SizedBox(height: ConsoleDensity.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(ConsoleDensity.radius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: Image.network(
                link,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(ConsoleDensity.lg),
                  child: Text('Görsel yüklenemedi.',
                      style: t.textTheme.bodySmall),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
