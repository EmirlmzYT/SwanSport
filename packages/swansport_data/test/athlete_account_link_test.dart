import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Sporcu kaydını hesaba bağlama (0076).
///
/// Kök neden şuydu: `athletes.profile_id` kod tabanında dört yerde
/// okunuyordu, hiçbir yerde yazılmıyordu. Bu testlerin bir kısmı o
/// regresyonu koruyor — yazma yolunun var olduğunu dosyadan doğruluyor.
void main() {
  final repo = Directory.current.path.replaceAll('\\', '/');
  final root = repo.endsWith('/packages/swansport_data')
      ? repo.substring(0, repo.length - '/packages/swansport_data'.length)
      : repo;

  group('Yazma yolu gerçekten var', () {
    test('servis profile_id yazan bir RPC çağırıyor', () {
      // 0076 öncesi bu arama boş dönerdi ve kimse fark etmezdi: sporcu
      // eklenir, hiçbir hata çıkmaz, ama o kayıt bir insana bağlanmazdı.
      final src = File('$root/packages/swansport_data/lib/src/'
              'supabase_athletes.dart')
          .readAsStringSync();
      expect(src.contains('create_athlete_from_member'), isTrue);
      expect(src.contains('link_athlete_to_member'), isTrue);
    });

    test('migration bir hesabı aynı kulüpte iki sporcu yapmayı engelliyor', () {
      final sql = File('$root/supabase/migrations/'
              '0076_athlete_account_link.sql')
          .readAsStringSync();
      expect(sql.contains('uq_athlete_profile_per_club'), isTrue);
      // Kısmi indeks şart: hesapsız sporcular birbirini engellememeli.
      expect(sql.contains('where profile_id is not null'), isTrue);
    });

    test('hesapsız sporcu ekleme yolu KALDIRILMADI', () {
      // Küçük yaştaki sporcuların giriş profili olmayabiliyor; bağlamayı
      // zorunlu kılmak onları kadro dışı bırakırdı.
      final src = File('$root/packages/swansport_data/lib/src/'
              'supabase_athletes.dart')
          .readAsStringSync();
      expect(src.contains('Future<void> addAthlete('), isTrue);
    });
  });

  group('Aday üye', () {
    ClubMemberCandidate c(String name) => ClubMemberCandidate.fromMap({
          'profile_id': 'p1',
          'full_name': name,
          'role': 'athlete',
          'joined_at': '2026-09-01T10:00:00Z',
        });

    test('alanlar okunuyor', () {
      final m = c('Emir Yılmaz');
      expect(m.profileId, 'p1');
      expect(m.fullName, 'Emir Yılmaz');
      expect(m.hasName, isTrue);
      expect(m.displayName, 'Emir Yılmaz');
      expect(m.joinedAt, isNotNull);
    });

    test('adı yazılmamış hesap ayırt ediliyor', () {
      // profiles.full_name varsayılanı boş dize. Ekranda boş satır
      // göstermek yerine antrenöre adı yazması gerektiği söyleniyor.
      expect(c('').hasName, isFalse);
      expect(c('   ').hasName, isFalse);
      expect(c('').displayName, 'Adı yazılmamış hesap');
    });

    test('eksik alanlar çökertmiyor', () {
      final m = ClubMemberCandidate.fromMap({'profile_id': 'p9'});
      expect(m.fullName, '');
      expect(m.role, 'athlete');
      expect(m.joinedAt, isNull);
    });
  });

  group('Bağlı olmayan sporcu', () {
    test('alanlar okunuyor', () {
      final a = UnlinkedAthlete.fromMap({
        'athlete_id': 'a1',
        'first_name': 'Emir',
        'last_name': 'Yılmaz',
        'status': 'active',
      });
      expect(a.athleteId, 'a1');
      expect(a.fullName, 'Emir Yılmaz');
    });

    test('soyadı boşsa tam ad boşlukla bitmiyor', () {
      // split_full_name tek kelimelik adda soyadı boş bırakıyor; ekranda
      // "Emir " gibi sondan boşluklu bir ad görünmemeli.
      final a = UnlinkedAthlete.fromMap({
        'athlete_id': 'a2',
        'first_name': 'Emir',
        'last_name': '',
      });
      expect(a.fullName, 'Emir');
    });

    test('eksik alanlar çökertmiyor', () {
      final a = UnlinkedAthlete.fromMap({'athlete_id': 'a3'});
      expect(a.fullName, '');
      expect(a.status, 'active');
    });
  });
}
