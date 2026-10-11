import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swansport_app/features/onboarding/application/setup_wizard_progress.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('existing accounts are not queued merely because seen is absent', () async {
    expect(await setupWizardRequired('existing'), isFalse);
  });

  test('registration survives confirmation delay and is account scoped', () async {
    await queueSetupWizard('new-account');
    expect(await setupWizardRequired('new-account'), isTrue);
    expect(await setupWizardRequired('another-account'), isFalse);
    await markSetupWizardSeen('another-account');
    expect(await setupWizardRequired('new-account'), isTrue);
    await markSetupWizardSeen('new-account');
    expect(await setupWizardRequired('new-account'), isFalse);
  });

  test('queueing twice is idempotent and completion remains seen', () async {
    await queueSetupWizard('new-account');
    await queueSetupWizard('new-account');
    await markSetupWizardSeen('new-account');
    await queueSetupWizard('new-account');
    expect(await setupWizardRequired('new-account'), isFalse);
  });
}
