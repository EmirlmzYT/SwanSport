import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  group('FaqEntry model', () {
    test('maps audience, active, sort order and content fields', () {
      final entry = FaqEntry.fromMap({
        'id': 'faq-123', 'question': 'Nasıl kayıt olurum?',
        'answer': 'Profil sekmesinden kayıt olabilirsiniz.', 'category': 'Kayıt',
        'route': '/profil', 'feature': 'season_setup',
        'audience': 'athlete', 'sort_order': 5, 'active': false,
      });
      expect(entry.id, 'faq-123');
      expect(entry.question, 'Nasıl kayıt olurum?');
      expect(entry.answer, 'Profil sekmesinden kayıt olabilirsiniz.');
      expect(entry.category, 'Kayıt');
      expect(entry.route, '/profil');
      expect(entry.feature, 'season_setup');
      expect(entry.audience, 'athlete');
      expect(entry.sortOrder, 5);
      expect(entry.active, false);
    });
    test('uses defaults for missing optional fields', () {
      final entry = FaqEntry.fromMap({
        'id': 'faq-456', 'question': 'Genel soru?', 'answer': 'Genel cevap.',
      });
      expect(entry.id, 'faq-456');
      expect(entry.category, 'genel');
      expect(entry.audience, 'everyone');
      expect(entry.sortOrder, 0);
      expect(entry.active, true);
      expect(entry.route, isNull);
      expect(entry.feature, isNull);
    });
  });
}
