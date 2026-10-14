import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

class MernisVerificationSection extends ConsumerWidget {
  const MernisVerificationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authSessionProvider).valueOrNull?.user.id;
    // Switching accounts destroys controllers/draft and ignores late responses.
    return _MernisForm(key: ValueKey(uid));
  }
}

class _MernisForm extends ConsumerStatefulWidget {
  const _MernisForm({super.key});
  @override
  ConsumerState<_MernisForm> createState() => _MernisFormState();
}

class _MernisFormState extends ConsumerState<_MernisForm> {
  final _form = GlobalKey<FormState>();
  final _national = TextEditingController();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _year = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _national.dispose(); _first.dispose(); _last.dispose(); _year.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    final availability = ref.read(mernisAvailabilityProvider);
    if (availability.isLoading || availability.hasError || availability.valueOrNull != true) return;
    setState(() { _busy = true; _error = null; });
    try {
      final result = await ref.read(verificationServiceProvider).verifyWithMernis(
        nationalId: _national.text, firstName: _first.text, lastName: _last.text,
        birthYear: int.parse(_year.text),
      );
      if (!mounted) return;
      if (result.success) {
        _national.clear(); _first.clear(); _last.clear(); _year.clear();
        // Service invalidates the authoritative gate, not a local success flag.
        final gate = await ref.read(myIdentityGateProvider.future);
        if (mounted && !gate.verified) setState(() => _error = 'Onay durumu yenileniyor. Lütfen tekrar kontrol edin.');
      } else { setState(() => _error = result.error); }
    } catch (_) {
      if (mounted) setState(() => _error = 'Onay durumu alınamadı. Belge incelemesini kullanabilirsiniz.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final availability = ref.watch(mernisAvailabilityProvider);
    final gate = ref.watch(myIdentityGateProvider);
    final available = !availability.isLoading && !availability.hasError && availability.valueOrNull == true;
    final verified = !gate.isLoading && !gate.hasError && gate.valueOrNull?.verified == true;
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MERNİS ile Anında T.C. Kimlik Doğrula', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        if (verified) Text('Kimliğiniz doğrulanmış. Kimlik onayı spor lisansı veya yaş doğrulaması yerine geçmez.',
          style: SwanType.bodySm(c.ink))
        else if (!available) Text('Otomatik doğrulama şu anda kapalı. Aşağıdan kimlik belgenizi yükleyip incelemeye gönderebilirsiniz.',
          style: SwanType.bodySm(c.inkMuted))
        else Form(key: _form, child: Column(children: [
          Text('Bilgiler yalnız kimlik doğrulama için gönderilir; doğum yılınızdan yapay bir tarih üretilmez. Numara kontrolü kimlik onayı değildir.',
            style: SwanType.bodySm(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),
          TextFormField(controller: _national, enabled: !_busy, maxLength: 11,
            style: SwanType.body(c.ink), keyboardType: TextInputType.number,
            autofillHints: const [], autocorrect: false, enableSuggestions: false,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'T.C. Kimlik No'),
            validator: (v) => isValidNationalId(v ?? '') ? null : 'Geçerli 11 haneli numara yazın.'),
          const SizedBox(height: SwanSpace.sm),
          TextFormField(controller: _first, enabled: !_busy, maxLength: 100,
            style: SwanType.body(c.ink), autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Ad (kimlikteki tam ad)'),
            validator: (v) => v?.trim().isNotEmpty == true ? null : 'Adınızı yazın.'),
          const SizedBox(height: SwanSpace.sm),
          TextFormField(controller: _last, enabled: !_busy, maxLength: 100,
            style: SwanType.body(c.ink), autocorrect: false, enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Soyad'),
            validator: (v) => v?.trim().isNotEmpty == true ? null : 'Soyadınızı yazın.'),
          const SizedBox(height: SwanSpace.sm),
          TextFormField(controller: _year, enabled: !_busy, maxLength: 4,
            style: SwanType.body(c.ink), keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Doğum Yılı'),
            validator: (v) { final year = int.tryParse(v ?? '');
              return year != null && year >= 1900 && year <= DateTime.now().toUtc().year
                ? null : 'Geçerli doğum yılı yazın.'; }),
          const SizedBox(height: SwanSpace.md),
          FilledButton(onPressed: _busy ? null : _submit,
            child: _busy ? const CircularProgressIndicator() : const Text('Doğrula ve Onayla')),
        ])),
        if (_error != null) ...[
          const SizedBox(height: SwanSpace.sm),
          Text(_error!, style: SwanType.bodySm(c.danger)),
        ],
        if (!verified) TextButton(onPressed: _busy ? null : () {
          ref.invalidate(mernisAvailabilityProvider);
          ref.invalidate(myCredentialsProvider);
          ref.invalidate(myIdentityGateProvider);
        }, child: const Text('Durumu Yenile')),
      ]),
    );
  }
}
