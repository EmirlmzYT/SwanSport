import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/settings/application/administration_controller.dart';
import 'package:swansport_app/features/settings/domain/administration.dart';

void main() {
  test('search and multi filters compose deterministically', () async {
    final subject = AdministrationController(FixtureAdministrationRepository());
    await Future<void>.delayed(Duration.zero);
    subject.search('selin');
    subject.role(AdminRole.branchManager);
    expect(subject.state.filtered.single.name, 'Selin Yılmaz');
    subject.status(UserStatus.suspended);
    expect(subject.state.filtered, isEmpty);
  });

  test('invitation lifecycle view-as and permissions work', () async {
    final subject = AdministrationController(FixtureAdministrationRepository());
    await Future<void>.delayed(Duration.zero);
    await subject.invite('Yeni Kullanıcı', 'new@test.dev', AdminRole.coach);
    expect(subject.state.users.last.status, UserStatus.invited);
    await subject.lifecycle(subject.state.users.last, UserStatus.active);
    expect(subject.state.users.last.status, UserStatus.active);
    subject.viewAs(subject.state.users.first);
    expect(subject.state.viewAs, isNotNull);
    subject.viewAs(null);
    expect(subject.state.viewAs, isNull);
    expect(permissionsFor(AdminRole.guardian).canView, isFalse);
  });
}
