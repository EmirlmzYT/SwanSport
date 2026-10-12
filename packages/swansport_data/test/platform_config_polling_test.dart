import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

class _Service extends Fake implements PlatformMissionControlService {
  int reads = 0;
  @override
  Future<PlatformConfig> config() async {
    reads++;
    return const PlatformConfig.empty();
  }
}
void main() {
  testWidgets('public config refreshes while subscribed, cancels timer on dispose', (tester) async {
    final service = _Service();
    final container = ProviderContainer(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      authSessionProvider.overrideWith((_) => Stream.value(null)),
      platformMissionControlServiceProvider.overrideWithValue(service),
    ]);
    final listener = container.listen(platformConfigProvider, (_, __) {});
    await tester.pump(); await tester.pump();
    final before = service.reads;
    expect(before, greaterThan(0));
    await tester.pump(const Duration(seconds: 31)); await tester.pump();
    expect(service.reads, greaterThan(before));
    listener.close(); container.dispose();
    final stopped = service.reads;
    await tester.pump(const Duration(seconds: 31));
    expect(service.reads, stopped);
  });
}
