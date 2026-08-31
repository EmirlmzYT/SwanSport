import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Kort kullanım ölçümü modelleri.
///
/// SQL tarafı burada test edilemiyor (oturum gerekiyor, `auth.uid()` null
/// döner) — ama **RPC'nin döndürdüğü şekli yanlış okumak** sessiz bir hata
/// üretir: sayı sıfır görünür, kimse fark etmez. Burada sabitlenen o.
void main() {
  group('CourtUsage', () {
    test('RPC satırını okur', () {
      final u = CourtUsage.fromMap(const {
        'slots_total': 42,
        'slots_done': 30,
        'slots_expired': 6,
        'slots_cancelled': 6,
        'unique_players': 17,
        'total_people': 58,
        'no_show_pct': 16.7,
        'checkin_pct': 71.4,
        'peak_hour': 19,
      });

      expect(u.slotsTotal, 42);
      expect(u.totalPeople, 58);
      expect(u.noShowPct, closeTo(16.7, 0.01));
      expect(u.peakHour, 19);
      expect(u.isEmpty, isFalse);
    });

    test('eksik alan çökertmez, sıfıra düşer', () {
      // Postgres `numeric` bazen int, bazen double geliyor; alan hiç
      // gelmezse de ekran açılmalı.
      final u = CourtUsage.fromMap(const {'slots_total': 3});
      expect(u.slotsTotal, 3);
      expect(u.noShowPct, 0);
      expect(u.peakHour, 0);
    });

    test('numeric int gelirse double\'a çevrilir', () {
      // `round(...,1)` tam sayı verirse Postgres 0 yerine 0 (int) döndürüyor;
      // ham `as double` cast'i burada patlardı.
      final u = CourtUsage.fromMap(const {'no_show_pct': 25, 'checkin_pct': 0});
      expect(u.noShowPct, 25.0);
      expect(u.checkinPct, 0.0);
    });

    test('isEmpty "veri yok" ile "sıfır" ayrımını taşır', () {
      // Ekran bu ayrıma dayanıyor: hiç kutu alınmamışsa "0 gelmeme oranı"
      // yazmak yanıltıcı — sistem kusursuz çalışıyormuş gibi görünür.
      expect(CourtUsage.empty.isEmpty, isTrue);
      expect(
        CourtUsage.fromMap(const {'slots_total': 1}).isEmpty,
        isFalse,
      );
    });
  });

  group('CourtUsageRow', () {
    test('kort kırılımını okur', () {
      final r = CourtUsageRow.fromMap(const {
        'court_id': 'c1',
        'court_name': 'Kort 1',
        'venue': 'Millet Bahçesi',
        'slots_total': 20,
        'slots_done': 18,
        'no_show_pct': 10.0,
        'fill_pct': 4.4,
      });

      expect(r.courtName, 'Kort 1');
      expect(r.venue, 'Millet Bahçesi');
      expect(r.fillPct, closeTo(4.4, 0.01));
    });

    test('hiç kullanılmamış kort de okunur', () {
      // `left join` sayesinde bu satır geliyor ve gelmeye devam etmeli:
      // "sıfır alınmış kort" belediye görüşmesinde bilgi taşıyor.
      final r = CourtUsageRow.fromMap(const {
        'court_id': 'c2',
        'court_name': 'Kort 2',
        'slots_total': 0,
        'slots_done': 0,
        'no_show_pct': 0,
        'fill_pct': 0,
      });

      expect(r.slotsTotal, 0);
      expect(r.venue, isNull);
      expect(r.fillPct, 0.0);
    });
  });
}
