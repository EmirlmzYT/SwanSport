import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/design/swan_type.dart';

/// Fişle hızlı gider girişi.
///
/// Amaç mükemmel kaydı almak değil, **fişin kaybolmasını önlemek.** Kulüp
/// yöneticisi marketten çıkarken fişi çekip tutarı yazıyor; kategori,
/// tedarikçi ve hangi hesaptan ödendiği masaüstünde tamamlanıyor.
///
/// Kayıt `status='draft'` olarak gidiyor ve raporlara girmiyor — yarım bir
/// kayıt toplamı bozmasın. Konsolda "3 taslak gider" rozetiyle görünüyor.
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

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;

    final categories = ref.watch(expenseCategoriesProvider);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Row(children: [
                  _back(context, surf, isDark, ink),
                  const SizedBox(width: 14),
                  Text('Gider Ekle', style: SwanType.h2(ink)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Fişi çek, tutarı yaz. Gerisini masaüstünden tamamlarsın.',
                  style:
                      SwanType.caption(SwanColors.textSecondary),
                ),
                const SizedBox(height: 20),

                _ReceiptBox(
                  image: _receipt,
                  surface: surf,
                  isDark: isDark,
                  onPick: _pick,
                  onClear: () => setState(() => _receipt = null),
                ),
                const SizedBox(height: 18),

                Text('Tutar', style: SwanType.h3(ink)),
                const SizedBox(height: 8),
                TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  style: SwanType.h1(ink),
                  decoration: InputDecoration(
                    hintText: '0,00',
                    suffixText: '₺',
                    filled: true,
                    fillColor: surf,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                Text('Kategori', style: SwanType.h3(ink)),
                const SizedBox(height: 8),
                categories.when(
                  loading: () =>
                      const LinearProgressIndicator(minHeight: 2, color: kTeal),
                  error: (e, _) => Text('Kategoriler alınamadı',
                      style: SwanType.caption(SwanColors.textSecondary)),
                  data: (list) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in list)
                        GestureDetector(
                          onTap: () => setState(() => _categoryId =
                              _categoryId == c.id ? null : c.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: _categoryId == c.id
                                  ? kTeal.withValues(alpha: .12)
                                  : surf,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _categoryId == c.id
                                    ? kTeal.withValues(alpha: .45)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              c.name,
                              style: SwanType.caption(
                                _categoryId == c.id ? kTeal : ink,
                                w: _categoryId == c.id
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                TextField(
                  controller: _note,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Not (isteğe bağlı)',
                    filled: true,
                    fillColor: surf,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: SwanType.caption(const Color(0xFFF43F5E))),
                ],

                const SizedBox(height: 22),
                GestureDetector(
                  onTap: _busy ? null : _save,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: kTeal.withValues(alpha: .34),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet',
                        style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _back(BuildContext context, Color surf, bool isDark, Color ink) =>
      GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: surf, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.arrow_back_rounded, size: 20, color: ink),
        ),
      );

  Future<void> _pick() async {
    final picked = await pickImage();
    if (picked != null && mounted) setState(() => _receipt = picked);
  }

  /// "1.234,56" ve "1234.56" ikisini de kabul eder.
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
      setState(() => _error = 'Geçerli bir tutar gir');
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

      await svc.addDraftExpense(
        clubId: club.id,
        amount: amount,
        categoryId: _categoryId,
        receiptPath: receiptPath,
        note: _note.text.trim(),
      );

      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Gider kaydedildi — masaüstünden tamamlayabilirsin'),
        backgroundColor: kTeal,
      ));
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

class _ReceiptBox extends StatelessWidget {
  const _ReceiptBox({
    required this.image,
    required this.surface,
    required this.isDark,
    required this.onPick,
    required this.onClear,
  });

  final PickedImage? image;
  final Color surface;
  final bool isDark;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (image == null) {
      return GestureDetector(
        onTap: onPick,
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kTeal.withValues(alpha: .3),
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long_rounded, size: 30, color: kTeal),
              const SizedBox(height: 10),
              Text('Fiş fotoğrafı ekle',
                  style: SwanType.bodySm(kTeal, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('isteğe bağlı ama sonradan çok işe yarar',
                  style: SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            image!.bytes,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: onClear,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
