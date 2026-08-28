import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_data/swansport_data.dart';

/// Modül görünürlüğü.
///
/// Kenar çubuğu ve yönlendirici aynı `visibleTo` kararını kullanıyor; buradaki
/// bir hata ya menüde görünüp açılmayan bir modül ya da tersini üretir.
///
/// **Not:** bu testler yalnızca *görünürlüğü* doğrular. Verinin korunması
/// RLS'in işi ve burada sınanmıyor — kenar çubuğunda modül gizlemek güvenlik
/// değildir.
void main() {
  const platformAdmin = SwanAccess(
    isPlatformAdmin: true,
    clubRole: 'member',
    coachLevel: 0,
    athleteKind: null,
  );
  const coach2 = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 2,
    athleteKind: null,
  );
  const coach4 = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'coach',
    coachLevel: 4,
    athleteKind: null,
  );
  const clubAdmin = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'club_admin',
    coachLevel: 0,
    athleteKind: null,
  );
  const athlete = SwanAccess(
    isPlatformAdmin: false,
    clubRole: 'athlete',
    coachLevel: 0,
    athleteKind: 'athlete_licensed',
  );

  List<String> visibleIds(SwanAccess a) =>
      kConsoleModules.where((m) => m.visibleTo(a)).map((m) => m.id).toList();

  group('kayıt tutarlılığı', () {
    test('modül kimlikleri benzersiz', () {
      final ids = kConsoleModules.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('rotalar benzersiz', () {
      final routes = kConsoleModules.map((m) => m.route).toList();
      expect(routes.toSet().length, routes.length);
    });

    test('her rota moduleForRoute ile bulunabiliyor', () {
      // Yönlendirici bu eşlemeye güveniyor.
      for (final m in kConsoleModules) {
        expect(moduleForRoute(m.route)?.id, m.id);
      }
      expect(moduleForRoute('/olmayan-rota'), isNull);
    });
  });

  group('kulüp yetkilisi', () {
    test('2. kademe antrenör kulüp modüllerini görür, tesisleri görmez', () {
      final ids = visibleIds(coach2);
      expect(ids, contains('athletes'));
      expect(ids, contains('schedule'));
      expect(ids, contains('attendance'));
      // Tesisler 4. kademeden açılıyor.
      expect(ids, isNot(contains('facilities')));
    });

    test('4. kademe antrenör tesisleri de görür', () {
      expect(visibleIds(coach4), contains('facilities'));
    });

    test('kulüp yöneticisi kademesiz de olsa tesisleri görür', () {
      expect(visibleIds(clubAdmin), contains('facilities'));
    });

    test('kulüp yetkilisi platform modüllerini görmez', () {
      final ids = visibleIds(coach4);
      expect(ids, isNot(contains('approvals')));
      expect(ids, isNot(contains('users')));
      expect(ids, isNot(contains('moderation')));
      expect(ids, isNot(contains('metrics')));
    });
  });

  group('platform yöneticisi', () {
    test('platform modüllerini görür', () {
      final ids = visibleIds(platformAdmin);
      expect(ids, contains('approvals'));
      expect(ids, contains('users'));
      expect(ids, contains('moderation'));
      expect(ids, contains('metrics'));
    });

    test('kulüpte görevi yoksa kulüp modüllerini görmez', () {
      // Platform yöneticiliği, kulüp verisine arayüzden erişim demek değil.
      final ids = visibleIds(platformAdmin);
      expect(ids, isNot(contains('athletes')));
      expect(ids, isNot(contains('attendance')));
    });
  });

  group('yetkisiz kullanıcı', () {
    test('sporcu konsolda hiçbir modül görmez', () {
      expect(visibleIds(athlete), isEmpty);
    });

    test('boş erişim profili hiçbir modül görmez', () {
      expect(visibleIds(SwanAccess.none), isEmpty);
    });
  });

  group('gelecek kitleler', () {
    test('federasyon, muhasebe ve pazar yeri henüz kimseye açık değil', () {
      // Yuvalar bilerek boş: modül yazılana kadar kimse görmemeli.
      for (final a in [platformAdmin, clubAdmin, coach4, athlete]) {
        expect(a.allows(ConsoleAudience.federation), isFalse);
        expect(a.allows(ConsoleAudience.accountant), isFalse);
        expect(a.allows(ConsoleAudience.marketplace), isFalse);
      }
    });
  });
}
