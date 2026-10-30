// Otomatik cihaz matrisi: widget/render testleridir. Fiziksel cihaz veya
// simülatör kanıtı DEĞİLDİR. Bkz. docs/swansport-pro-device-visual-acceptance.md
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_app.dart';
import 'package:swansport_pro/features/auth/pro_login_screen.dart';
import 'package:swansport_pro/features/operations/pro_club_context_selector.dart';
import 'package:swansport_pro/shell/pro_navigation.dart';
import 'package:swansport_pro/shell/pro_shell.dart';

const _longEmail =
    'cok.uzun.bir.eposta.adresi.operasyon.sorumlusu@buyuksehir-spor-kulubu.org.tr';
const _longClub =
    'Büyükşehir Belediyesi Gençlik ve Spor Kulübü Derneği Atletizm Şubesi';
const _secondClub =
    'Anadolu Yıldızları Olimpik Hazırlık ve Gelişim Spor Kulübü';
const _longMatch =
    '2026–2027 Türkiye Süper Gençler Şampiyonası Final Müsabakası: '
    'Büyükşehir Belediyesi GSK vs Anadolu Yıldızları SK';

class _FakeAccountSessionService implements AccountSessionService {
  @override
  Future<void> signIn(
      {required String email, required String password}) async {}

  @override
  Future<void> signOut() async {}
}

Session _session() {
  return Session(
    accessToken: 'token',
    tokenType: 'bearer',
    user: User(
      id: 'user-device-matrix',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-10-26',
      email: _longEmail,
    ),
  );
}

class _Viewport {
  const _Viewport(this.width, this.height);
  final double width;
  final double height;
  @override
  String toString() => '${width.toInt()}x${height.toInt()}';
}

const _viewports = <_Viewport>[
  _Viewport(320, 568),
  _Viewport(360, 800),
  _Viewport(375, 812),
  _Viewport(390, 844),
  _Viewport(430, 932),
  _Viewport(768, 1024),
  _Viewport(1024, 768),
  _Viewport(1440, 900),
];

const _scales = <double>[1.0, 1.3, 1.6];

const _tabs = <String>['Panel', 'Görevler', 'Takvim', 'Gelen Kutusu', 'Hesap'];

/// Görünümü fiziksel piksel ve gerçek platform text scale ile ayarlar.
void _configureView(
  WidgetTester tester,
  _Viewport viewport, {
  required double scale,
  bool notch = true,
  double keyboard = 0,
}) {
  const dpr = 3.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(viewport.width * dpr, viewport.height * dpr);
  final mobile = viewport.width < 600;
  tester.view.padding = FakeViewPadding(
    top: notch && mobile ? 47 * dpr : 0,
    bottom: notch && mobile ? 34 * dpr : 0,
  );
  tester.view.viewPadding = tester.view.padding;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * dpr);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Widget _app() {
  return ProviderScope(
    overrides: [
      accountSessionServiceProvider
          .overrideWithValue(_FakeAccountSessionService()),
      authSessionProvider.overrideWith((ref) => Stream.value(_session())),
      swanAccessProvider.overrideWithValue(
        const SwanAccess(
          isPlatformAdmin: true,
          clubRole: 'club_admin',
          coachLevel: 3,
          athleteKind: null,
        ),
      ),
      proAuthorizedClubsProvider.overrideWithValue(
        const AsyncData([
          ClubRef(id: 'club-1', name: _longClub, role: 'club_admin'),
          ClubRef(id: 'club-2', name: _secondClub, role: 'coach'),
        ]),
      ),
      activeClubProvider.overrideWith(
        (ref) async =>
            const ClubRef(id: 'club-1', name: _longClub, role: 'club_admin'),
      ),
      unifiedCalendarMonthProvider.overrideWith(
        (ref, month) async => UnifiedCalendarData([
          UnifiedCalendarEvent(
            id: 'match-long-1',
            type: CalendarEventType.officialFederation,
            title: _longMatch,
            startsAt: DateTime.utc(month.year, month.month, 15, 16, 30),
            place: 'Atatürk Olimpiyat Kompleksi Merkez Atletizm Pist Sahası',
            status: 'scheduled',
          ),
        ]),
      ),
      proUnreadNotificationsCountProvider.overrideWith((ref) async => 128),
    ],
    child: const ProApp(),
  );
}

Future<List<String>> _visitTabs(WidgetTester tester) async {
  final failures = <String>[];
  for (final tab in _tabs) {
    await tester.tap(find.text(tab).last, warnIfMissed: false);
    await tester.pumpAndSettle();
    final error = tester.takeException();
    if (error != null) failures.add('$tab: $error');
  }
  return failures;
}

void main() {
  group('Pro otomatik cihaz matrisi — shell ve beş ana sekme', () {
    for (final viewport in _viewports) {
      for (final scale in _scales) {
        testWidgets('$viewport @ ${scale}x notch/home-indicator',
            (tester) async {
          _configureView(tester, viewport, scale: scale);
          await tester.pumpWidget(_app());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ProShell), findsOneWidget);
          expect(await _visitTabs(tester), isEmpty);
        });
      }
    }

    for (final viewport in const [
      _Viewport(320, 568),
      _Viewport(390, 844),
      _Viewport(768, 1024),
      _Viewport(1024, 768),
    ]) {
      testWidgets('$viewport @ 2.0x kritik yüzeyler', (tester) async {
        _configureView(tester, viewport, scale: 2.0);
        await tester.pumpWidget(_app());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(await _visitTabs(tester), isEmpty);
      });
    }
  });

  group('Pro otomatik cihaz matrisi — SafeArea, seçiciler ve hedefler', () {
    testWidgets('mobil alt navigasyon home indicator üstünde kalır',
        (tester) async {
      const viewport = _Viewport(390, 844);
      _configureView(tester, viewport, scale: 1.0);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      for (final tab in _tabs) {
        final item = find.widgetWithText(ProNavigationItem, tab);
        final rect = tester.getRect(item);
        expect(rect.bottom, lessThanOrEqualTo(viewport.height - 34),
            reason: '$tab home indicator altına giriyor');
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(rect.width, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('üst çentik içeriği örtmez', (tester) async {
      const viewport = _Viewport(390, 844);
      _configureView(tester, viewport, scale: 1.0);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      final brand = tester.getRect(find.text('SwanSport Pro').first);
      expect(brand.top, greaterThanOrEqualTo(47));
    });

    testWidgets('masaüstü sol navigasyon 48 px hedefleri ve semantics korur',
        (tester) async {
      _configureView(tester, const _Viewport(1440, 900), scale: 1.0);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byType(ProBottomNavigationBar), findsNothing);
      for (final tab in _tabs) {
        final rect = tester.getRect(
          find
              .ancestor(
                  of: find.text(tab).first, matching: find.byType(InkWell))
              .first,
        );
        expect(rect.height, greaterThanOrEqualTo(48), reason: tab);
      }
      expect(find.bySemanticsLabel(RegExp('Gelen Kutusu')), findsWidgets);
    });

    testWidgets('mobil alt navigasyon TalkBack/VoiceOver etiketleri taşır',
        (tester) async {
      final handle = tester.ensureSemantics();
      _configureView(tester, const _Viewport(360, 800), scale: 1.0);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      for (final tab in _tabs) {
        expect(find.bySemanticsLabel(RegExp('^$tab')), findsWidgets,
            reason: tab);
      }
      handle.dispose();
    });

    testWidgets(
        'mobil workspace switcher ve kulüp seçici 320x568 @ 2.0x taşmadan açılır',
        (tester) async {
      _configureView(tester, const _Viewport(320, 568), scale: 2.0);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final wsBtn = find.byKey(const ValueKey('pro_workspace_dropdown_button'));
      expect(wsBtn, findsOneWidget);
      expect(tester.getSize(wsBtn).height, greaterThanOrEqualTo(48));

      await tester.tap(wsBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Çalışma Alanı Değiştir'), findsOneWidget);
      Navigator.of(tester.element(find.text('Çalışma Alanı Değiştir'))).pop();
      await tester.pumpAndSettle();

      final clubBtn = find.byKey(const Key('pro-mobile-club-selector-button'));
      expect(clubBtn, findsOneWidget);
      expect(tester.getSize(clubBtn).height, greaterThanOrEqualTo(48));

      await tester.tap(clubBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Kulüp Değiştir'), findsOneWidget);
    });
  });

  group('Pro otomatik cihaz matrisi — giriş ekranı ve klavye', () {
    Widget login() {
      return ProviderScope(
        overrides: [
          accountSessionServiceProvider
              .overrideWithValue(_FakeAccountSessionService()),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: const ProLoginScreen(),
        ),
      );
    }

    for (final scale in const [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('320x568 @ ${scale}x klavye açık giriş butonu erişilebilir',
          (tester) async {
        _configureView(
          tester,
          const _Viewport(320, 568),
          scale: scale,
          keyboard: 300,
        );
        await tester.pumpWidget(login());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.widgetWithText(TextField, 'Şifre'));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FilledButton, 'Giriş Yap');
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final rect = tester.getRect(button);
        expect(rect.bottom, lessThanOrEqualTo(568 - 300 + 0.5),
            reason: 'Giriş butonu klavye altında kalıyor');
        expect(rect.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      });
    }

    for (final viewport in _viewports) {
      testWidgets('$viewport giriş ekranı taşmaz', (tester) async {
        _configureView(tester, viewport, scale: 1.3);
        await tester.pumpWidget(login());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('SwanSport Pro'), findsWidgets);
      });
    }

    testWidgets('şifre göster/gizle 48 px ve semantik etiketli',
        (tester) async {
      final handle = tester.ensureSemantics();
      _configureView(tester, const _Viewport(360, 800), scale: 1.0);
      await tester.pumpWidget(login());
      await tester.pumpAndSettle();
      final toggle = find.byTooltip('Şifreyi göster');
      expect(toggle, findsOneWidget);
      final size = tester.getSize(toggle);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });
}
