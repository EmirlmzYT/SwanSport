import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

class PhoneVerificationSection extends ConsumerStatefulWidget {
  const PhoneVerificationSection({super.key});

  @override
  ConsumerState<PhoneVerificationSection> createState() =>
      _PhoneVerificationSectionState();
}

class _PhoneVerificationSectionState
    extends ConsumerState<PhoneVerificationSection> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(verificationServiceProvider);
      if (_sentTo == null) {
        final phone = _phone.text.replaceAll(RegExp(r'\s'), '');
        await service.requestPhoneVerification(phone);
        if (mounted) setState(() => _sentTo = phone);
      } else {
        await service.confirmPhoneVerification(_sentTo!, _code.text.trim());
        if (!mounted) return;
        ref.invalidate(myVenueVerificationTierProvider);
        final tier = await ref.read(myVenueVerificationTierProvider.future);
        if (tier != 'phone' && tier != 'id') {
          throw StateError(
              'Doğrulama henüz onaylanmadı. Kodunu kontrol edip yeniden dene.');
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SwanSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Telefon doğrulaması', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        if (access.hasVerificationTier('phone'))
          Text('Tesis ve partner işlemleri için doğrulaman tamam.',
              style: SwanType.bodySm(c.success))
        else ...[
          Text(
              'Rezervasyon ve partner iletişimi için SMS koduyla telefonunu doğrula. Onaylı kimliğin varsa bu adım gerekmez.',
              style: SwanType.bodySm(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),
          TextField(
            controller: _phone,
            enabled: !_busy && _sentTo == null,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
                labelText: 'Telefon (+90…)', hintText: '+905321234567'),
          ),
          if (_sentTo != null) ...[
            const SizedBox(height: SwanSpace.md),
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration:
                  const InputDecoration(labelText: 'SMS doğrulama kodu'),
            ),
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _sentTo = null;
                          _code.clear();
                        }),
                child: const Text('Numarayı değiştir / yeniden kod iste')),
          ],
          if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
          const SizedBox(height: SwanSpace.md),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy
                  ? 'İşleniyor…'
                  : _sentTo == null
                      ? 'SMS kodu gönder'
                      : 'Kodu doğrula')),
        ],
      ]),
    );
  }
}
