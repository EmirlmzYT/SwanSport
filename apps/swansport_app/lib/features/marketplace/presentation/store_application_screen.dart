import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// Mağaza başvurusu ve durumu.
///
/// Sıfır ürün satmak isteyen kullanıcı buradan başvuruyor. Başvuru
/// platform yöneticisi tarafından konsolda inceleniyor.
///
/// **Vergi numarası, fatura ve şirket belgesi istenmiyor.** İlk sürümde
/// gerekmediği için toplanmıyor; toplanan her kişisel veri korunması gereken
/// bir yük ve kullanılmayacaksa taşınmamalı. Gerekirse yalnızca platform
/// yöneticisinin erişebildiği bir alana eklenecek.
class StoreApplicationScreen extends ConsumerStatefulWidget {
  const StoreApplicationScreen({super.key});

  @override
  ConsumerState<StoreApplicationScreen> createState() =>
      _StoreApplicationScreenState();
}

class _StoreApplicationScreenState
    extends ConsumerState<StoreApplicationScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final stores = ref.watch(myStoresProvider).valueOrNull ?? const <StoreRow>[];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(SwanSpace.lg),
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Mağaza', style: SwanType.h2(c.ink)),
                ]),
                const SizedBox(height: SwanSpace.xl),

                // Mevcut başvurular önce: kullanıcı ikinci kez başvurmadan
                // önce ilkinin ne durumda olduğunu görsün.
                if (stores.isNotEmpty) ...[
                  Text('Başvurularım', style: SwanType.h3(c.ink)),
                  const SizedBox(height: SwanSpace.sm),
                  for (final s in stores) _storeRow(c, s),
                  const SizedBox(height: SwanSpace.xl),
                ],

                Text(
                  stores.isEmpty ? 'Mağaza başvurusu' : 'Yeni başvuru',
                  style: SwanType.h3(c.ink),
                ),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  'Onaylanan mağazalar sıfır ürün satabilir. Bireysel '
                  'kullanıcılar yalnızca ikinci el ürün yayınlar.',
                  style: SwanType.caption(c.inkMuted),
                ),
                const SizedBox(height: SwanSpace.lg),

                _field(c, _name, 'Mağaza adı', 'Konya Spor Market'),
                _field(c, _desc, 'Açıklama', 'Ne satıyorsunuz?', lines: 3),
                _field(c, _note, 'Başvuru notu',
                    'Yöneticinin bilmesi gerekenler', lines: 2),

                const SizedBox(height: SwanSpace.lg),
                GestureDetector(
                  onTap: _saving ? null : _apply,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentFill,
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    child: Text(_saving ? 'Gönderiliyor…' : 'Başvur',
                        style: SwanType.body(Colors.white, w: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _storeRow(SwanPalette c, StoreRow s) {
    final tone = switch (s.status) {
      'approved' => c.success,
      'rejected' || 'suspended' => c.danger,
      _ => c.warning,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.sm),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(s.name,
                style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
          ),
          Text(s.statusLabel,
              style: SwanType.caption(tone, w: FontWeight.w800)),
        ]),
        // Ret sebebi gösteriliyor: sebebini bilmeyen kullanıcı aynı
        // başvuruyu tekrar gönderiyor ve iki taraf da zaman kaybediyor.
        if ((s.reviewNote ?? '').isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(s.reviewNote!, style: SwanType.caption(c.inkMuted)),
        ],
      ]),
    );
  }

  Widget _field(SwanPalette c, TextEditingController ctrl, String label,
          String hint,
          {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.md),
        child: TextField(
          controller: ctrl,
          minLines: lines,
          maxLines: lines,
          style: SwanType.bodySm(c.ink),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: SwanType.caption(c.inkMuted),
            hintText: hint,
            hintStyle: SwanType.caption(c.inkMuted),
            filled: true,
            fillColor: c.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.md, vertical: SwanSpace.md),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                borderSide: BorderSide(color: c.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.sm),
                borderSide: BorderSide(color: c.accent, width: 1.5)),
          ),
        ),
      );

  Future<void> _apply() async {
    final c = context.swan;
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mağaza adı gerekli'),
          backgroundColor: c.danger));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(marketplaceServiceProvider).applyForStore(
            name: _name.text,
            description: _desc.text,
            note: _note.text,
          );
      ref.invalidate(myStoresProvider);
      _name.clear();
      _desc.clear();
      _note.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Başvurun alındı, inceleniyor'),
            backgroundColor: c.accentFill));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: c.danger));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
