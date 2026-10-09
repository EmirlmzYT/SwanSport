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
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(financeOperationsSummaryProvider);
      ref.invalidate(clubOperationsSummaryProvider);
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
  final _searchCtrl = TextEditingController();

  String _targetKind = 'expense';
  String? _selectedTargetId;
  ClosedPeriodCandidateEntry? _selectedTargetEntry;
  String? _kindFilter; // null for all, or 'expense', 'payment', 'donation'
  int _offset = 0;
  static const int _pageSize = 50;
  String _searchQuery = '';
  bool _submitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onFilterChanged(String? newKind) {
    setState(() {
      _kindFilter = newKind;
      _offset = 0;
      if (_selectedTargetEntry != null &&
          newKind != null &&
          _selectedTargetEntry!.targetKind != newKind) {
        _selectedTargetId = null;
        _selectedTargetEntry = null;
        _amountCtrl.clear();
        _reasonCtrl.clear();
      }
    });
  }

  void _onSearchChanged(String text) {
    setState(() {
      _searchQuery = text.trim();
      _offset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final pageAsync = ref.watch(
      closedPeriodCandidatesPageProvider((
        targetKind: _kindFilter,
        query: _searchQuery.isEmpty ? null : _searchQuery,
        limit: _pageSize,
        offset: _offset,
      ),),
    );

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Yeni Kapanmış Dönem Ters Kaydı',
                      style: SwanType.h3(c.ink),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  'Kapanmış bir mali dönemdeki işlemin iadesi veya iptali için cari döneme ters hareket oluşturulur.',
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.md),
                // Arama kutusu ve filtre çipleri
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Hedef kayıtlarda ara (Türkçe duyarlı)...',
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: c.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: _onSearchChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.xs),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: _kindFilter == null,
                      onSelected: (_) => _onFilterChanged(null),
                    ),
                    ChoiceChip(
                      label: const Text('Giderler'),
                      selected: _kindFilter == 'expense',
                      onSelected: (_) => _onFilterChanged('expense'),
                    ),
                    ChoiceChip(
                      label: const Text('Tahsilatlar'),
                      selected: _kindFilter == 'payment',
                      onSelected: (_) => _onFilterChanged('payment'),
                    ),
                    ChoiceChip(
                      label: const Text('Bağışlar'),
                      selected: _kindFilter == 'donation',
                      onSelected: (_) => _onFilterChanged('donation'),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),
                pageAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.only(bottom: SwanSpace.sm),
                    child: Text(
                      'İşlemler yüklenemedi: $e',
                      style: SwanType.caption(c.danger),
                    ),
                  ),
                  data: (page) {
                    final entries = page.entries;
                    final totalCount = page.totalCount;

                    // Seçili kayıt başka sayfada kalsa dahi dropdown'da tutulmasını sağla
                    final displayItems =
                        List<ClosedPeriodCandidateEntry>.from(entries);
                    if (_selectedTargetEntry != null &&
                        (_kindFilter == null ||
                            _selectedTargetEntry!.targetKind == _kindFilter) &&
                        !displayItems.any((e) =>
                            e.entryId == _selectedTargetEntry!.entryId,)) {
                      displayItems.insert(0, _selectedTargetEntry!);
                    }

                    if (displayItems.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(SwanSpace.md),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                        ),
                        child: Text(
                          _searchQuery.isNotEmpty || _kindFilter != null
                              ? 'Arama kriterlerine uygun kapanmış dönem kaydı bulunamadı.'
                              : 'Kapanmış dönemlerde düzeltilebilecek (bakiye kalan) bir işlem kaydı bulunamadı.',
                          style: SwanType.caption(c.inkMuted),
                        ),
                      );
                    }

                    final totalPages = totalCount > 0
                        ? ((totalCount - 1) ~/ _pageSize) + 1
                        : 1;
                    final currentPage = (_offset ~/ _pageSize) + 1;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey('target-$_selectedTargetId-$_kindFilter'),
                          initialValue: _selectedTargetId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Düzeltilecek Hedef Kayıt *',
                            filled: true,
                            fillColor: c.bg,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(SwanRadius.md),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          dropdownColor: c.surface,
                          items: displayItems.map((e) {
                            return DropdownMenuItem<String>(
                              value: e.entryId,
                              child: Text(
                                '[${e.targetKindLabel}] ${e.label} • ₺${e.amount} (Kalan: ₺${e.remainingAmount})',
                                style: SwanType.bodySm(c.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Lütfen düzeltilecek hedef işlemi seçiniz';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            if (val != null) {
                              final entry = displayItems
                                  .firstWhere((e) => e.entryId == val);
                              setState(() {
                                _selectedTargetId = val;
                                _selectedTargetEntry = entry;
                                _targetKind = entry.targetKind;
                                _amountCtrl.text =
                                    entry.remainingAmount.toString();
                                _reasonCtrl.text =
                                    'Ters kayıt (${entry.targetKindLabel}): ${entry.label}';
                              });
                            }
                          },
                        ),
                        if (totalCount > _pageSize) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Toplam $totalCount kayıt (Sayfa $currentPage / $totalPages)',
                                style: SwanType.caption(c.inkMuted),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left,
                                        size: 20,),
                                    onPressed: _offset > 0
                                        ? () => setState(
                                              () => _offset =
                                                  (_offset - _pageSize)
                                                      .clamp(0, totalCount),
                                            )
                                        : null,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right,
                                        size: 20,),
                                    onPressed:
                                        (_offset + _pageSize) < totalCount
                                            ? () => setState(
                                                  () => _offset += _pageSize,
                                                )
                                            : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: SwanSpace.sm),
                // Hedef tür ve ters hareket yönü bilgi kartı (tür seçilen kayıttan türetilir)
                Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _targetKind == 'expense'
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: _targetKind == 'expense'
                            ? const Color(0xFF10B981)
                            : c.danger,
                        size: 20,
                      ),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTargetEntry != null
                                  ? 'Hedef: ${_selectedTargetEntry!.targetKindLabel} (Hesap: ${_selectedTargetEntry!.accountName})'
                                  : 'İşlem Türü: Gider Ters Kaydı',
                              style:
                                  SwanType.caption(c.ink, w: FontWeight.bold),
                            ),
                            Text(
                              _targetKind == 'expense'
                                  ? 'Cari Dönem Etkisi: Kasa Girişi (Gider Mahsubu/İade)'
                                  : 'Cari Dönem Etkisi: Kasa Çıkışı (Ödeme/Bağış İadesi)',
                              style: SwanType.caption(c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Ters Kayıt Tutarı (₺) *',
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
                    if (_selectedTargetEntry != null &&
                        n > _selectedTargetEntry!.remainingAmount) {
                      return 'Tutar kalan iade edilebilir tutardan (₺${_selectedTargetEntry!.remainingAmount}) büyük olamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: SwanSpace.sm),
                TextFormField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Düzeltme Gerekçesi *',
                    hintText:
                        'Örn: Kapanmış dönemdeki mükerrer fatura iadesi cari hesaba mahsup edilmiştir.',
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
                          'Ters Kayıt Oluştur',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
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

      final parsed =
          num.parse(_amountCtrl.text.trim().replaceAll(',', '.')).abs();

      if (_selectedTargetId == null) {
        throw Exception('Düzeltme yapılacak hedef işlem seçilmelidir');
      }

      await ref.read(financeOpsServiceProvider).createAdjustment(
            clubId: club.id,
            targetKind: _targetKind,
            targetId: _selectedTargetId,
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
