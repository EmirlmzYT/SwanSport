import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/navigation/app_routes.dart';
import 'package:swansport_app/app/navigation/swan_destination.dart';

void main() {
  group('SwanDestination Metadata', () {
    test('dört sabit branch doğru indeks ve rotalarla eşleşir', () {
      expect(SwanShellBranch.feed.index, 0);
      expect(SwanShellBranch.feed.rootRoute, AppRoutes.feed);

      expect(SwanShellBranch.explore.index, 1);
      expect(SwanShellBranch.explore.rootRoute, AppRoutes.explore);

      expect(SwanShellBranch.messages.index, 2);
      expect(SwanShellBranch.messages.rootRoute, AppRoutes.messages);

      expect(SwanShellBranch.profile.index, 3);
      expect(SwanShellBranch.profile.rootRoute, AppRoutes.profile);

      expect(SwanShellBranch.fromRoute(AppRoutes.feed), SwanShellBranch.feed);
      expect(
          SwanShellBranch.fromRoute(AppRoutes.explore), SwanShellBranch.explore);
      expect(SwanShellBranch.fromRoute(AppRoutes.messages),
          SwanShellBranch.messages);
      expect(SwanShellBranch.fromRoute(AppRoutes.profile),
          SwanShellBranch.profile);
    });

    test('tam ekran ve operasyon rotalarında alt gezinme gizlenir', () {
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.auth), isTrue);
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.demoRole), isTrue);
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.credentials), isTrue);
      expect(SwanDestination.shouldHideBottomNav('/dogrulama'), isTrue);
      expect(
          SwanDestination.shouldHideBottomNav(AppRoutes.trainingSession), isTrue);
      expect(
          SwanDestination.shouldHideBottomNav(AppRoutes.createWorkout), isTrue);
      expect(
          SwanDestination.shouldHideBottomNav(AppRoutes.trainingResult), isTrue);
      expect(SwanDestination.shouldHideBottomNav('/sepet'), isTrue);

      // Dinamik operasyon yolları
      expect(SwanDestination.shouldHideBottomNav('/hakem/canli/abc-123'), isTrue);
      expect(SwanDestination.shouldHideBottomNav('/hakem/rapor/abc-123'), isTrue);
      expect(SwanDestination.shouldHideBottomNav('/hakem/esame/abc-123'), isTrue);
      expect(
          SwanDestination.shouldHideBottomNav('/swan-id/dogrula/token123'), isTrue);
      expect(
          SwanDestination.shouldHideBottomNav('/canli-mac/match-123'), isTrue);
    });

    test('ana branch köklerinde alt gezinme gösterilir', () {
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.feed), isFalse);
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.explore), isFalse);
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.messages), isFalse);
      expect(SwanDestination.shouldHideBottomNav(AppRoutes.profile), isFalse);
    });

    test('AppRoutes dinamik rota üreticileri geçerli URI döner', () {
      expect(AppRoutes.athleteMatchCard('m1'), '/mac-kartim/m1');
      expect(AppRoutes.liveMatch('m2'), '/canli-mac/m2');
      expect(AppRoutes.refereeLineup('m3'), '/hakem/esame/m3');
      expect(AppRoutes.refereeLive('m4'), '/hakem/canli/m4');
      expect(AppRoutes.refereeReport('m5'), '/hakem/rapor/m5');

      final resultUrl = AppRoutes.officialResult(
        notificationId: 'notif-1',
        matchId: 'match-1',
        childId: 'child-1',
      );
      final parsed = Uri.parse(resultUrl);
      expect(parsed.path, '/resmi-sonuc');
      expect(parsed.queryParameters['notification'], 'notif-1');
      expect(parsed.queryParameters['match'], 'match-1');
      expect(parsed.queryParameters['child'], 'child-1');
    });
  });
}
