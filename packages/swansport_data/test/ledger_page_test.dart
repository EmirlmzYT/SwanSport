import 'package:swansport_data/swansport_data.dart';
import 'package:test/test.dart';

void main() {
  group('LedgerPage.fromRows', () {
    test('ilk satırdaki toplamı korur, yalnızca sayfayı çözer', () {
      final page = LedgerPage.fromRows([
        {
          'entry_id': 'one',
          'moved_on': '2026-08-29',
          'direction': 'in',
          'label': 'Aidat',
          'category': 'Aidat',
          'counterpart': '#A3F91C',
          'account': 'Banka',
          'amount': 500,
          'status': 'confirmed',
          'total_count': 137,
        },
      ]);

      expect(page.totalCount, 137);
      expect(page.entries, hasLength(1));
      expect(page.entries.single.id, 'one');
    });

    test('boş yanıt sıfır toplamlı boş sayfadır', () {
      final page = LedgerPage.fromRows(const []);

      expect(page.totalCount, 0);
      expect(page.entries, isEmpty);
    });
  });
}
