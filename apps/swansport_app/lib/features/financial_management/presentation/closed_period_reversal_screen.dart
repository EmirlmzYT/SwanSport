import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Kapanmış dönem ters işlem ve mali düzeltme yönetim ekranı.
///
/// Kapanmış mali dönemlerdeki kayıtlar silinemez veya geriye dönük
/// değiştirilemez. Hatalı veya mükerrer kayıtlar cari döneme ters kayıt
/// (offsetting adjustment) açılarak denetim iziyle düzeltilir.
class ClosedPeriodReversalScreen extends ConsumerStatefulWidget {
  const ClosedPeriodReversalScreen({super.key});

  @override
  ConsumerState<ClosedPeriodReversalScreen> createState() =>
      _ClosedPeriodReversalScreenState();
}

class _ClosedPeriodReversalScreenState
    extends ConsumerState<ClosedPeriodReversalScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final adjustmentsAsync = ref.watch(financeAdjustmentsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      bottomNavigationBar: const SwanBottomNav(),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          backgroundColor: c.accent,
          foregroundColor: const Color(0xFF0D141F),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Yeni Ters İşlem',
            style: SwanType.caption(const Color(0xFF0D141F)),
          ),
          onPressed: () => _showNewAdjustmentSheet(context),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(financeAdjustmentsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SwanSpace.lg,
              SwanSpace.md,
              SwanSpace.lg,
              120,
            ),
            children: [
              SwanPageHeader(
                title: 'Ters İşlem ve Düzeltme',
                subtitle: 'Kapanmış dönem denetim düzeltmeleri',
                onBack: () => Navigator.maybePop(context),
              ),
              const SizedBox(height: SwanSpace.md),
              _buildExplanationCard(c),
              const SizedBox(height: SwanSpace.md),
              _buildFilterTabs(c),
              const SizedBox(height: SwanSpace.md),
              adjustmentsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(SwanSpace.md),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Kayıtlar yüklenirken hata oluştu: $err',
                    style: SwanType.caption(c.danger),
                  ),
                ),
                data: (list) {
                  final filtered = list.where((a) {
                    if (_statusFilter == 'all') return true;
                    return a.status == _statusFilter;
                  }).toList();

                  if (filtered.isEmpty) {
                    return _buildEmptyState(c);
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: SwanSpace.sm),
                    itemBuilder: (context, i) =>
                        _buildAdjustmentCard(filtered[i], c),
                  );
                },
              ),
              const SizedBox(height: SwanSpace.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: c.accent, size: 22),
          const SizedBox(width: SwanSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mali Kilit ve Denetim Güvencesi',
                  style: SwanType.h3(c.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kapanmış mali dönem kayıtları doğrudan silinemez veya geriye dönük değiştirilemez. Hatalı işlemler cari döneme ters kayıt açılarak yönetici onayıyla uygulanır.',
                  style: SwanType.caption(c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'Tümü', c),
          const SizedBox(width: SwanSpace.xs),
          _filterChip('pending', 'Beklemede', c),
          const SizedBox(width: SwanSpace.xs),
          _filterChip('approved', 'Onaylandı', c),
          const SizedBox(width: SwanSpace.xs),
          _filterChip('rejected', 'Reddedildi', c),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label, SwanPalette c) {
    final active = _statusFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _statusFilter = key),
      selectedColor: c.accent.withValues(alpha: 0.2),
      backgroundColor: c.surface,
      labelStyle: TextStyle(
        color: active ? c.accent : c.inkMuted,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: active ? c.accent : c.line,
      ),
    );
  }

  Widget _buildEmptyState(SwanPalette c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: c.inkMuted,
            ),
            const SizedBox(height: SwanSpace.sm),
            Text(
              'Düzeltme kaydı bulunamadı',
              style: SwanType.h3(c.ink),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerektiğinde yeni bir ters işlem başlatabilirsiniz.',
              style: SwanType.caption(c.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdjustmentCard(FinanceAdjustment adj, SwanPalette c) {
    final (statusColor, statusBg) = switch (adj.status) {
      'approved' => (
          c.success,
          c.success.withValues(alpha: 0.1),
        ),
      'rejected' => (
          c.danger,
          c.danger.withValues(alpha: 0.1),
        ),
      _ => (
          c.accent,
          c.accent.withValues(alpha: 0.1),
        ),
    };

    final isNegative = adj.amount < 0;
    final amountSign = isNegative ? '-' : '+';
    final absAmount = adj.amount.abs();

    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text(
                  adj.targetKindLabel,
                  style: SwanType.caption(c.ink),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text(
                  adj.statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  adj.reason,
                  style: SwanType.body(c.ink),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Text(
                '$amountSign₺${absAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isNegative ? c.danger : c.success,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tarih: ${adj.createdAt.day.toString().padLeft(2, '0')}.${adj.createdAt.month.toString().padLeft(2, '0')}.${adj.createdAt.year}',
                style: SwanType.caption(c.inkMuted),
              ),
              if (adj.approvedAt != null)
                Text(
                  'Onay: ${adj.approvedAt!.day.toString().padLeft(2, '0')}.${adj.approvedAt!.month.toString().padLeft(2, '0')}.${adj.approvedAt!.year}',
                  style: SwanType.caption(c.inkMuted),
                ),
            ],
          ),
          if (adj.status == 'pending') ...[
            Divider(height: 20, color: c.line),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reddet'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.danger,
                    side: BorderSide(color: c.danger),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _handleApproval(adj.id, false),
                ),
                const SizedBox(width: SwanSpace.xs),
                FilledButton.icon(
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Onayla'),
                  style: FilledButton.styleFrom(
                    backgroundColor: c.success,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _handleApproval(adj.id, true),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleApproval(String adjustmentId, bool approve) async {
    final action = approve ? 'onaylamak' : 'reddetmek';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Düzeltmeyi Onayla' : 'Düzeltmeyi Reddet'),
        content: Text(
          'Bu ters kayıt işlemini $action istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(approve ? 'Onayla' : 'Reddet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(financeOpsServiceProvider).approveAdjustment(
            adjustmentId: adjustmentId,
            approve: approve,
          );
      ref.invalidate(financeAdjustmentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Düzeltme onaylandı.' : 'Düzeltme reddedildi.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İşlem başarısız: $e')),
        );
      }
    }
  }

  void _showNewAdjustmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewAdjustmentModal(
        onSaved: () {
          ref.invalidate(financeAdjustmentsProvider);
        },
      ),
    );
  }
}

class _NewAdjustmentModal extends ConsumerStatefulWidget {
  const _NewAdjustmentModal({required this.onSaved});
  final VoidCallback onSaved;

  @override
  ConsumerState<_NewAdjustmentModal> createState() =>
      _NewAdjustmentModalState();
}

class _NewAdjustmentModalState extends ConsumerState<_NewAdjustmentModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _targetKind = 'expense';
  bool _isReversal = true;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Yeni Ters Kayıt / Düzeltme',
                    style: SwanType.h3(c.ink),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              DropdownButtonFormField<String>(
                initialValue: _targetKind,
                decoration: InputDecoration(
                  labelText: 'İşlem Türü',
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                dropdownColor: c.surface,
                items: const [
                  DropdownMenuItem(
                    value: 'expense',
                    child: Text('Gider Ters Kaydı (İade / İptal)'),
                  ),
                  DropdownMenuItem(
                    value: 'payment',
                    child: Text('Ödeme / Aidat Düzeltmesi'),
                  ),
                  DropdownMenuItem(
                    value: 'invoice',
                    child: Text('Fatura Düzeltmesi'),
                  ),
                  DropdownMenuItem(
                    value: 'donation',
                    child: Text('Bağış Kaydı Düzeltmesi'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _targetKind = val);
                },
              ),
              const SizedBox(height: SwanSpace.sm),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Ters Kayıt (Eksi)')),
                      selected: _isReversal,
                      onSelected: (val) => setState(() => _isReversal = true),
                      selectedColor: c.accent.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: _isReversal ? c.accent : c.line,
                      ),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Artı Düzeltme')),
                      selected: !_isReversal,
                      onSelected: (val) => setState(() => _isReversal = false),
                      selectedColor: c.accent.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: !_isReversal ? c.accent : c.line,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SwanSpace.sm),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Tutar (₺)',
                  hintText: '0.00',
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen tutar giriniz';
                  }
                  final n = num.tryParse(val.replaceAll(',', '.'));
                  if (n == null || n <= 0) {
                    return 'Geçerli ve sıfırdan büyük bir tutar giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: SwanSpace.sm),
              TextFormField(
                controller: _reasonCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Düzeltme Gerekçesi',
                  hintText:
                      'Örn: 2026/08 dönemindeki mükerrer fatura iadesi cari hesaba mahsup edilmiştir.',
                  filled: true,
                  fillColor: c.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Lütfen en az 5 karakterlik açıklama giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: SwanSpace.md),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: const Color(0xFF0D141F),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Düzeltme Kaydı Oluştur',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) {
        throw Exception('Aktif kulüp bulunamadı');
      }

      var parsed = num.parse(_amountCtrl.text.trim().replaceAll(',', '.'));
      if (_isReversal) {
        parsed = -parsed.abs();
      } else {
        parsed = parsed.abs();
      }

      await ref.read(financeOpsServiceProvider).createAdjustment(
            clubId: club.id,
            targetKind: _targetKind,
            amount: parsed,
            reason: _reasonCtrl.text.trim(),
          );

      widget.onSaved();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ters kayıt başarıyla oluşturuldu.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

