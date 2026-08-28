import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// `SwanAccess` — kim neyi görebilir hesabı.
///
/// Bu sınıf iki uygulamanın da menüsünü belirliyor, yani buradaki bir hata
/// hem mobilde hem konsolda yanlış ekran açar. Sağlayıcıyı değil saf hesabı
/// test ediyoruz: Supabase'e ihtiyaç duymadan kuralların kendisi sınanabilir.
void main() {
  group('SwanAccess.isClubStaff', () {
    test('kulüpteki görev tek başına yeter', () {
      const a = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'coach',
        coachLevel: 0,
        athleteKind: null,
      );
      expect(a.isClubStaff, isTrue);
    });

    test('onaylanmış antrenörlük belgesi tek başına yeter', () {
      // Kritik senaryo: kimlik onaylandığında hiçbir yer profiles.role'ü
      // güncellemiyor. Rol hâlâ "member" iken kişi antrenör olmuş sayılmalı.
      const a = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'member',
        coachLevel: 2,
        athleteKind: null,
      );
      expect(a.isClubStaff, isTrue);
    });

    test('sporcu ya da veli kulüp yetkilisi değildir', () {
      const athlete = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'athlete',
        coachLevel: 0,
        athleteKind: 'athlete_licensed',
      );
      const parent = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'parent',
        coachLevel: 0,
        athleteKind: null,
      );
      expect(athlete.isClubStaff, isFalse);
      expect(parent.isClubStaff, isFalse);
    });

    test('hiçbir şeyi olmayan kişi yetkili değildir', () {
      expect(SwanAccess.none.isClubStaff, isFalse);
      expect(SwanAccess.none.isPlatformAdmin, isFalse);
    });
  });

  group('SwanAccess.hasCoachLevel', () {
    test('eşik 0 ise herkes geçer', () {
      expect(SwanAccess.none.hasCoachLevel(0), isTrue);
    });

    test('kademe eşiği karşılanmalı', () {
      const level2 = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'coach',
        coachLevel: 2,
        athleteKind: null,
      );
      expect(level2.hasCoachLevel(2), isTrue);
      expect(level2.hasCoachLevel(3), isFalse);
      expect(level2.hasCoachLevel(4), isFalse);
    });

    test('kulüp yöneticisi kademesiz de olsa geçer', () {
      // Kulübün sahibinin kendi tesisini yönetememesi saçma olurdu.
      const admin = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'club_admin',
        coachLevel: 0,
        athleteKind: null,
      );
      expect(admin.hasCoachLevel(4), isTrue);
      expect(admin.isClubAdmin, isTrue);
    });

    test('yüksek kademe düşük eşiği de karşılar', () {
      const level5 = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'coach',
        coachLevel: 5,
        athleteKind: null,
      );
      for (var i = 1; i <= 5; i++) {
        expect(level5.hasCoachLevel(i), isTrue, reason: 'eşik $i');
      }
    });
  });

  group('SwanAccess sporcu türü', () {
    test('lisanslı ile ferdi ayrılır', () {
      const licensed = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'athlete',
        coachLevel: 0,
        athleteKind: 'athlete_licensed',
      );
      const individual = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'member',
        coachLevel: 0,
        athleteKind: 'athlete_individual',
      );

      expect(licensed.isVerifiedAthlete, isTrue);
      expect(licensed.isLicensedAthlete, isTrue);

      expect(individual.isVerifiedAthlete, isTrue);
      expect(individual.isLicensedAthlete, isFalse);
    });

    test('belgesi olmayan doğrulanmış sporcu sayılmaz', () {
      const a = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'athlete',
        coachLevel: 0,
        athleteKind: null,
      );
      expect(a.isVerifiedAthlete, isFalse);
    });
  });

  group('birden fazla kimlik bir arada', () {
    test('ferdi sporcu + 2. kademe antrenör ikisi birden olabilir', () {
      // Kullanıcının bildirdiği gerçek hata buydu: hesap ferdi sporcu olarak
      // doğrulanmışken antrenörlüğü onaylandı, ama üst rütbe ekranları
      // açılmadı. İkisi de aynı anda geçerli olmalı.
      const a = SwanAccess(
        isPlatformAdmin: false,
        clubRole: 'member',
        coachLevel: 2,
        athleteKind: 'athlete_individual',
      );

      expect(a.isClubStaff, isTrue, reason: 'antrenörlük tarafı');
      expect(a.isVerifiedAthlete, isTrue, reason: 'sporculuk tarafı');
      expect(a.hasCoachLevel(2), isTrue);
    });

    test('platform yöneticisi kulüp yetkisinden bağımsızdır', () {
      const a = SwanAccess(
        isPlatformAdmin: true,
        clubRole: 'member',
        coachLevel: 0,
        athleteKind: null,
      );
      expect(a.isPlatformAdmin, isTrue);
      expect(a.isClubStaff, isFalse);
    });
  });
}
