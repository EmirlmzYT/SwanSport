import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  for (final scenario in <({String name, Size size, bool detail})>[
    (name: 'mobile', size: const Size(390, 844), detail: false),
    (name: 'wide', size: const Size(1440, 900), detail: false),
    (name: 'detail_mobile', size: const Size(390, 844), detail: true),
    (name: 'detail_wide', size: const Size(1440, 900), detail: true),
  ]) {
    testWidgets('professional review ${scenario.name} visual evidence',
        (tester) async {
      tester.view
        ..physicalSize = scenario.size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(
              const SwanAccess(
                isPlatformAdmin: true,
                clubRole: null,
                coachLevel: 0,
                athleteKind: null,
              ),
            ),
            pendingCredentialsProvider.overrideWith(
              (ref) async => const [
                CredentialRow(
                  id: 'credential-1',
                  kind: 'coach',
                  status: 'pending',
                  personName: 'Ayşe Yılmaz',
                  sportCode: 'basketbol',
                  sportName: 'Basketbol',
                  coachLevel: 3,
                ),
                CredentialRow(
                  id: 'credential-2',
                  kind: 'athlete_licensed',
                  status: 'pending',
                  personName: 'Mehmet Kaya',
                  sportCode: 'tenis',
                  sportName: 'Tenis',
                ),
              ],
            ),
            sportlessCredentialsProvider.overrideWith((ref) async => const []),
            reviewLogProvider.overrideWith((ref) async => const []),
            credentialDocumentsProvider('credential-1').overrideWith(
              (ref) async => const [
                (
                  docType: 'coach_certificate',
                  url: 'https://signed.invalid/credential-1',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ProTheme.dark(),
            home: const RepaintBoundary(
              key: Key('professional-review-evidence'),
              child: ProOperationsFeatureHost(
                child: PlatformProfessionalReviewScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario.detail) {
        await tester.tap(find.text('Ayşe Yılmaz'));
        await tester.pumpAndSettle();
      }

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const Key('professional-review-evidence')),
        matchesGoldenFile(
          'goldens/professional_review_${scenario.name}.png',
        ),
      );
    });
  }
}
