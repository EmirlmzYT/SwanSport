import 'dart:async';

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
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_countdown <= 1) {
        timer.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  String _formatFriendlyError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('expired')) {
      return 'Doğrulama kodunun süresi dolmuş. Lütfen yeni bir kod isteyin.';
    }
    if (message.contains('invalid token') || message.contains('invalid otp')) {
      return 'Girdiğiniz doğrulama kodu hatalı. Lütfen kontrol edip tekrar deneyin.';
    }
    if (message.contains('sms provider') || message.contains('phone provider') ||
        message.contains('phone auth is disabled') || message.contains('not enabled')) {
      return 'SMS doğrulama servisi henüz aktif değil. Lütfen aşağıdaki Kimlik Belgesi Doğrulama adımıyla devam edin.';
    }
    return '$error';
  }

  Future<void> _submit({bool resend = false}) async {
    if (_busy || (resend && _countdown > 0)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(verificationServiceProvider);
      if (_sentTo == null || resend) {
        final phone = _sentTo ?? _phone.text.trim();
        await service.requestPhoneVerification(phone);
        if (mounted) {
          setState(() {
            _sentTo = normalizePhoneNumber(phone);
            _phone.text = _sentTo!;
            _code.clear();
          });
          _startCountdown();
        }
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
      if (mounted) setState(() => _error = _formatFriendlyError(e));
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
        if (access.hasVerificationTier('phone') || access.hasVerificationTier('id'))
          Container(
            padding: const EdgeInsets.all(SwanSpace.md),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(SwanRadius.md),
              border: Border.all(color: c.success.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.check_circle_rounded, color: c.success, size: 20),
              const SizedBox(width: SwanSpace.sm),
              Expanded(child: Text('Tesis ve partner işlemleri için doğrulamanız tamam.',
                style: SwanType.bodySm(c.success, w: FontWeight.w600))),
            ]),
          )
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
            style: SwanType.bodySm(c.ink),
            decoration: const InputDecoration(
                labelText: 'Telefon Numarası', hintText: '0532 123 45 67'),
          ),
          if (_sentTo != null) ...[
            const SizedBox(height: SwanSpace.md),
            TextField(
              controller: _code,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: SwanType.bodySm(c.ink),
              decoration:
                  const InputDecoration(labelText: '6 Haneli SMS Kodu', hintText: '123456'),
            ),
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _sentTo = null;
                          _code.clear();
                          _error = null;
                          _countdown = 0;
                          _timer?.cancel();
                        }),
                child: Text('Numarayı Değiştir', style: SwanType.bodySm(c.accent))),
            if (_countdown > 0)
              Text('Tekrar gönder: ${_countdown}s', style: SwanType.caption(c.inkMuted))
            else
              TextButton(
                onPressed: _busy ? null : () => _submit(resend: true),
                child: Text('Tekrar Kod Gönder', style: SwanType.bodySm(c.accent)),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: SwanSpace.sm),
            Container(
              padding: const EdgeInsets.all(SwanSpace.sm),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Text(_error!, style: SwanType.caption(c.danger)),
            ),
          ],
          const SizedBox(height: SwanSpace.md),
          FilledButton(
              onPressed: _busy ? null : () => _submit(),
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
