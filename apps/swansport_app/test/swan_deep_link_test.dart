import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/app_navigator.dart';

void main() {
  testWidgets('observer tolerates an unavailable native links plugin',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SwanDeepLinkObserver(child: SizedBox()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('Swan ID uygulama bağlantısını doğrulama rotasına çevirir', () {
    const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
    expect(
      swanDeepLinkRoute(Uri.parse('swansport://swan-id/dogrula/$token')),
      '/swan-id/dogrula/$token',
    );
    expect(
      swanDeepLinkRoute(Uri.parse('swansport://swan-id/dogrula/kisa')),
      isNull,
    );
  });

  test('profil uygulama bağlantısı güvenli query rotasına çevrilir', () {
    expect(
      swanDeepLinkRoute(Uri.parse('swansport://profil/profile-123')),
      '/profil?id=profile-123',
    );
    expect(
      swanDeepLinkRoute(Uri.parse('https://example.com/profil/profile-123')),
      isNull,
    );
    expect(
      swanDeepLinkRoute(
        Uri.parse('https://swansport.pages.dev/#/profil?id=profile-123'),
      ),
      '/profil?id=profile-123',
    );
  });

  test('HTTPS Swan ID bağlantısını uygulama rotasına çevirir', () {
    const token = '0123456789abcdef0123456789abcdef0123456789abcdef';
    expect(
      swanDeepLinkRoute(
        Uri.parse('https://swansport.pages.dev/#/swan-id/dogrula/$token'),
      ),
      '/swan-id/dogrula/$token',
    );
  });
}
