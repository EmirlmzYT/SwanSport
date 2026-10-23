import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/navigation/route_link_adapter.dart';

void main() {
  const token = '0123456789abcdef0123456789abcdef0123456789abcdef';

  group('RouteLinkAdapter', () {
    test('normalizes custom scheme Swan ID links', () {
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('swansport://swan-id/dogrula/$token'),
        ),
        '/swan-id/dogrula/$token',
      );
    });

    test('normalizes hash and path based production links', () {
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('https://swansport.com.tr/#/swan-id/dogrula/$token'),
        ),
        '/swan-id/dogrula/$token',
      );
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('https://swansport.com.tr/swan-id/dogrula/$token'),
        ),
        '/swan-id/dogrula/$token',
      );
    });

    test('keeps only the supported profile query', () {
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('https://swansport.com.tr/profil?id=user-1&admin=true'),
        ),
        '/profil?id=user-1',
      );
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('swansport://kulup-profil/club-1'),
        ),
        '/kulup-profil?id=club-1',
      );
    });

    test('rejects unknown hosts, malformed tokens and arbitrary routes', () {
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('https://example.com/#/swan-id/dogrula/$token'),
        ),
        isNull,
      );
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('swansport://swan-id/dogrula/not-a-token'),
        ),
        isNull,
      );
      expect(
        RouteLinkAdapter.fromExternalUri(
          Uri.parse('swansport://settings'),
        ),
        isNull,
      );
    });
  });
}
