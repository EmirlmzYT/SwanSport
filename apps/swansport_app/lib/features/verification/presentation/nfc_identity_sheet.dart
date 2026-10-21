import 'package:flutter/material.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// Otomatik NFC doğrulaması üretim adaptörü hazır olana kadar özelliğin
/// durumunu açıklar. Kart algılama tek başına kimlik doğrulaması değildir.
Future<bool?> showNfcIdentityVerificationSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NfcIdentityAvailabilitySheet(),
    );

class _NfcIdentityAvailabilitySheet extends StatelessWidget {
  const _NfcIdentityAvailabilitySheet();

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg,
          SwanSpace.md,
          SwanSpace.lg,
          SwanSpace.xl,
        ),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SwanRadius.lg),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.lg),
            Icon(Icons.nfc_rounded, color: c.inkMuted, size: 42),
            const SizedBox(height: SwanSpace.md),
            Text(
              'NFC ile otomatik doğrulama hazırlanıyor',
              textAlign: TextAlign.center,
              style: SwanType.h3(c.ink),
            ),
            const SizedBox(height: SwanSpace.sm),
            Text(
              'Kimlik çipini güvenli biçimde okuyacak kurumsal doğrulama '
              'adaptörü henüz bağlı değil. Kart algılama tek başına kimlik '
              'veya canlılık doğrulaması sayılmaz.',
              textAlign: TextAlign.center,
              style: SwanType.bodySm(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.md),
            Container(
              padding: const EdgeInsets.all(SwanSpace.md),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(SwanRadius.md),
                border: Border.all(color: c.warning.withValues(alpha: 0.35)),
              ),
              child: Text(
                'Şimdilik aşağıdaki belge yükleme alanlarını kullan. '
                'Başvurun yetkili incelemesinden sonra sonuçlanır.',
                style: SwanType.bodySm(c.ink),
              ),
            ),
            const SizedBox(height: SwanSpace.lg),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: c.accentFill,
                foregroundColor: c.onAccent,
              ),
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Belge yüklemeye devam et'),
            ),
          ],
        ),
      ),
    );
  }
}
