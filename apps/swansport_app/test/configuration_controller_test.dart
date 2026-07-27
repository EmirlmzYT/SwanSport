import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/configuration/application/configuration_controller.dart';
import 'package:swansport_app/features/configuration/domain/club_configuration.dart';

void main() {
  test('search filters modules categories and settings', () {
    final c = ConfigurationController(FixtureConfigurationRepository());
    c.search('KVKK');
    expect(c.state.filtered.single.id, 'legal');
    c.search('');
    c.filter(ConfigurationCategory.branding);
    expect(c.state.filtered.single.id, 'branding');
  });
  test('profile, history, validation and permissions are deterministic', () {
    final c = ConfigurationController(FixtureConfigurationRepository());
    c.createProfile('Turnuva');
    expect(c.state.profiles, hasLength(2));
    final p = c.state.profiles.last;
    c.duplicate(p);
    expect(c.state.profiles, hasLength(3));
    c.archive(p);
    expect(c.state.profiles[1].archived, isTrue);
    c.update('club_name', 'Yeni Kulüp');
    expect(c.state.history.single.previousValue, 'Kadıköy SK');
    expect(c.state.validations, isNotEmpty);
    final readOnly = ConfigurationController(
      FixtureConfigurationRepository(),
      canEdit: false,
    );
    readOnly.update('club_name', 'Engelli');
    expect(readOnly.state.settings.first.value, 'Kadıköy SK');
  });
}
