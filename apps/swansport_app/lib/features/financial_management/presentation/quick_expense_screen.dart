import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/media/image_pick.dart';

/// Fişle hızlı gider girişi.
///
/// Stitch "Calm Athletic Modernism" (harcama_giri_i_ve_masraf_onay) tasarımına uyumlu:
/// - OCR / Kamera / Galeri Fiş Yükleme Kartı
/// - ₺ Vurgulu Büyük Tutar Girişi ve Hızlı Seçim Hapları
/// - Kategori Seçim Hapları
/// - Harcama Açıklaması ve Taslak Oluşturma
class QuickExpenseScreen extends ConsumerStatefulWidget {
  const QuickExpenseScreen({super.key});

  @override
  ConsumerState<QuickExpenseScreen> createState() => _QuickExpenseScreenState();
}

class _QuickExpenseScreenState extends ConsumerState<QuickExpenseScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  PickedImage? _receipt;
  String? _categoryId;
  bool _busy = false;
  String? _error;

  /// İşlem kimliği — idempotency güvencesi.
  final String _opId = newOpId();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;
    final surf = palette.surface;

    final categories = ref.watch(expenseCategoriesProvider);
    final club = ref.watch(activeClubProvider).valueOrNull;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildHeader(context, palette, club?.name ?? 'Kulüp'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    children: [
                      // Subtitle Header
                      Text(
                        'BÜTÇE VE FİNANS YÖNETİMİ',
                        style: SwanType.caption(
                          palette.inkMuted,
                          w: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hızlı Masraf Fişi Girişi',
                        style: SwanType.h2(palette.ink),
                      ),
                      const SizedBox(height: 14),

                      // Receipt Upload Box (OCR / Camera Zone)
                      _buildReceiptBox(palette, surf),
                      const SizedBox(height: 18),

                      // Amount Input Card
                      _buildAmountInput(palette, surf),
                      const SizedBox(height: 18),

                      // Category Pills
                      _buildCategorySelection(categories, palette, surf),
                      const SizedBox(height: 18),

                      // Description Input
                      _buildDescriptionInput(palette, surf),

                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette.danger.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: palette.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: SwanType.caption(
                                    palette.danger,
                                    w: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      _buildSubmitButton(palette),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    SwanPalette palette,
    String clubName,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: palette.line.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clubName • Finans',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                  Text(
                    'Yeni Gider Girişi',
                    style: SwanType.h3(palette.ink),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Taslak',
                  style: SwanType.caption(palette.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptBox(SwanPalette palette, Color surf) {
    if (_receipt != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_rounded,
                      size: 18,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Fiş Eklendi',
                      style: SwanType.caption(palette.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _receipt = null),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _receipt!.bytes,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _receipt!.name,
              style: SwanType.caption(palette.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pick,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 26,
                color: palette.accent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kamera veya Galeriden Fiş Seç',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              'Görsel buluta yüklenir ve masraf kaydına iliştirilir',
              style: SwanType.caption(palette.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountInput(SwanPalette palette, Color surf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Harcama Tutarı',
          style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              Text(
                '₺',
                style: SwanType.h2(palette.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: SwanType.h2(palette.ink),
                  decoration: const InputDecoration(
                    hintText: '0,00',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _amount.text = '150';
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '150₺',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySelection(
    AsyncValue<List<ExpenseCategory>> categories,
    SwanPalette palette,
    Color surf,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Harcama Kategorisi',
          style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        categories.when(
          loading: () =>
              LinearProgressIndicator(minHeight: 2, color: palette.accent),
          error: (_, __) => Text(
            'Kategoriler yüklenemedi',
            style: SwanType.caption(palette.inkMuted),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Text(
                'Tanımlı kategori bulunmuyor',
                style: SwanType.caption(palette.inkMuted),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in list)
                  GestureDetector(
                    onTap: () => setState(
                      () => _categoryId = _categoryId == c.id ? null : c.id,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _categoryId == c.id ? palette.accent : surf,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _categoryId == c.id
                              ? palette.accent
                              : palette.line,
                        ),
                      ),
                      child: Text(
                        c.name,
                        style: SwanType.caption(
                          _categoryId == c.id ? Colors.white : palette.ink,
                          w: _categoryId == c.id
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionInput(SwanPalette palette, Color surf) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Açıklama & Not',
          style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surf,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.line),
          ),
          child: TextField(
            controller: _note,
            maxLines: 2,
            style: SwanType.bodySm(palette.ink),
            decoration: InputDecoration(
              hintText: 'Örn: 10 Adet antrenman hedef kağıdı temini...',
              hintStyle: SwanType.caption(palette.inkMuted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(SwanPalette palette) {
    return GestureDetector(
      onTap: _busy ? null : _save,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Gideri Kaydet / Taslak Oluştur',
                      style: SwanType.bodySm(
                        Colors.white,
                        w: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _pick() async {
    final picked = await pickImage();
    if (picked != null && mounted) {
      setState(() => _receipt = picked);
    }
  }

  num? _parseAmount(String raw) {
    var s = raw.trim().replaceAll(' ', '').replaceAll('₺', '');
    if (s.isEmpty) return null;
    if (s.contains(',')) s = s.replaceAll('.', '').replaceAll(',', '.');
    final v = num.tryParse(s);
    return (v == null || v <= 0) ? null : v;
  }

  Future<void> _save() async {
    final amount = _parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Geçerli bir tutar giriniz');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) throw StateError('Aktif kulüp yok');
      final svc = ref.read(expenseServiceProvider);

      String? receiptPath;
      if (_receipt != null) {
        receiptPath = await svc.uploadReceipt(
          clubId: club.id,
          bytes: _receipt!.bytes,
          fileName: _receipt!.name,
        );
      }

      await ref.read(financeOpsServiceProvider).createDraftExpense(
            clubId: club.id,
            amount: amount,
            opId: _opId,
            receiptPath: receiptPath,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );

      navigator.pop();
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final accent = (isDark ? SwanPalette.dark : SwanPalette.light).accent;
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'Gider kaydedildi — masaüstünden tamamlayabilirsiniz',
          ),
          backgroundColor: accent,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Kaydedilemedi: $e';
          _busy = false;
        });
      }
    }
  }
}
