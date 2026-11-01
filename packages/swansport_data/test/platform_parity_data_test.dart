import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('federation staff projection exposes only identity and display name',
      () {
    final assignment = FederationStaffAssignment.fromMap({
      'profile_id': 'profile-1',
      'profiles': {'full_name': 'Ada Yetkili'},
    });
    expect(assignment.profileId, 'profile-1');
    expect(assignment.name, 'Ada Yetkili');
  });

  test('platform-only providers fail closed without backend and access',
      () async {
    final container = ProviderContainer(
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(false),
        swanAccessProvider.overrideWithValue(SwanAccess.none),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(platformRssSourcesProvider.future), isEmpty);
    expect(
      await container.read(federationStaffProvider('federation-1').future),
      isEmpty,
    );
  });
}
