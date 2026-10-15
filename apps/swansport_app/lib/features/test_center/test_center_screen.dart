import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/config/app_environment.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../demo/demo_role.dart';

const testCenterRoute = '/test-merkezi';
final localTestCenterRequestedProvider = Provider<bool>((ref) => false);
typedef LocalTestRestart = void Function(String route, String? error);
final localTestRestartProvider = Provider<LocalTestRestart?>((ref) => null);
final localTestInitialRouteProvider = Provider<String>((ref) => testCenterRoute);
final localTestErrorProvider = Provider<String?>((ref) => null);
final localTestCenterEnabledProvider = Provider<bool>((ref) {
  final env = ref.watch(appEnvironmentProvider);
  final config = ref.watch(supabaseConfigProvider);
  return ref.watch(localTestCenterRequestedProvider) && env.isDevelopment &&
      env.enableDebugTools && config.isConfigured && isLocalTestBackend(config.url);
});

String _label(LocalTestPersona role) => switch (role) {
  LocalTestPersona.viewer => 'Taraftar olarak aç',
  LocalTestPersona.manager => 'Yönetici olarak aç',
  LocalTestPersona.coach => 'Antrenör olarak aç',
  LocalTestPersona.athlete => 'Sporcu olarak aç',
  LocalTestPersona.accountant => 'Muhasebeci olarak aç',
};
String _hint(LocalTestPersona role) => switch (role) {
  LocalTestPersona.viewer => 'Akış ve keşfet; kulüp yönetimi görünmemeli.',
  LocalTestPersona.manager => 'Hazır test kulübü, kadro, takvim ve yönetim.',
  LocalTestPersona.coach => '3. kademe antrenör; yoklama ve antrenman.',
  LocalTestPersona.athlete => 'Kendi sporcu kartı ve aidatı; yönetim yetkisi yok.',
  LocalTestPersona.accountant => 'Mali defter; sporcu adları görünmemeli.',
};
String _startRoute(LocalTestPersona role) => switch (role) {
  LocalTestPersona.viewer => '/akis',
  LocalTestPersona.manager => '/athletes',
  LocalTestPersona.coach => '/attendance',
  LocalTestPersona.athlete => '/aidatlarim',
  LocalTestPersona.accountant => '/finans',
};

class TestCenterScreen extends ConsumerStatefulWidget {
  const TestCenterScreen({super.key});
  @override
  ConsumerState<TestCenterScreen> createState() => _TestCenterScreenState();
}

class _TestCenterScreenState extends ConsumerState<TestCenterScreen> {
  LocalTestPersona? _busy;
  String? _error;

  Future<void> _open(LocalTestPersona role) async {
    if (_busy != null || !ref.read(localTestCenterEnabledProvider)) return;
    setState(() { _busy = role; _error = null; });
    try {
      ref.read(demoRoleProvider.notifier).state = null;
      await ref.read(localTestAccountServiceProvider).switchTo(role);
      if (!mounted) return;
      final restart = ref.read(localTestRestartProvider);
      if (restart != null) { restart(_startRoute(role), null); return; }
      ref.read(selectedClubIdProvider.notifier).state = null;
      ref.invalidate(activeClubProvider);
      ref.invalidate(currentProfileProvider);
      Navigator.of(context).pushNamedAndRemoveUntil(_startRoute(role), (_) => false);
    } catch (_) {
      final message = 'Giriş yapılamadı. Yerel backend ve test hesaplarının kurulumunu kontrol et.';
      if (mounted && ref.read(localTestRestartProvider) != null) {
        ref.read(localTestRestartProvider)!(testCenterRoute, message);
        return;
      }
      if (mounted) setState(() {
        _error = 'Giriş yapılamadı. Yerel backend açık mı? Kurulum betiğini yeniden çalıştır. '
            'Bu düğme canlı hesaba giriş yapmaz.';
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    if (!ref.watch(localTestCenterEnabledProvider)) {
      return Scaffold(body: Center(child: Text('Test Merkezi bu ortamda kapalı.',
          style: SwanType.body(c.ink))));
    }
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final error = _error ?? ref.watch(localTestErrorProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: Text('Yerel Test Merkezi', style: SwanType.h3(c.ink))),
      body: ListView(padding: const EdgeInsets.all(SwanSpace.lg), children: [
        Text('Bir rol seç, uygulamayı dene.', style: SwanType.h2(c.ink)),
        const SizedBox(height: SwanSpace.sm),
        Text('Yalnız bilgisayarındaki test verileri kullanılır. Gerçek Auth, SwanAccess ve '
            'RLS çalışır; rol taklidi yapılmaz.', style: SwanType.bodySm(c.inkMuted)),
        const SizedBox(height: SwanSpace.lg),
        Text('Aktif hesap: ${profile?.fullName ?? 'Giriş yapılmadı'}',
            style: SwanType.bodySm(c.ink)),
        if (error != null) Padding(padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
            child: Text(error, style: SwanType.bodySm(c.danger))),
        for (final role in LocalTestPersona.values) Padding(
          padding: const EdgeInsets.only(top: SwanSpace.md),
          child: Material(color: c.surface, borderRadius: BorderRadius.circular(SwanRadius.md),
            child: Padding(padding: const EdgeInsets.all(SwanSpace.lg), child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                FilledButton(onPressed: _busy == null ? () => _open(role) : null,
                    child: Text(_busy == role ? 'Giriş yapılıyor…' : _label(role))),
                const SizedBox(height: SwanSpace.sm),
                Text(_hint(role), style: SwanType.bodySm(c.inkMuted)),
              ])),
          ),
        ),
        const SizedBox(height: SwanSpace.xl),
        Text('Her ekrandaki “Test Merkezi” düğmesiyle geri dönüp rol değiştirebilirsin. '
            'Yazdığın kayıtlar yerelde kalır; sıfırlama betiği otomatik veri silmez.',
            style: SwanType.caption(c.inkMuted)),
      ]),
    );
  }
}

/// Separate from the five-tab navigation. Visible only in the dedicated local build.
class LocalTestCenterFrame extends StatelessWidget {
  const LocalTestCenterFrame({required this.child, required this.onOpen, super.key});
  final Widget child;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Column(children: [
      Material(color: c.surfaceAlt, child: SafeArea(bottom: false,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
          child: Row(children: [
            Expanded(child: Text('YEREL TEST · Canlı veri yok', style: SwanType.caption(c.ink))),
            TextButton(onPressed: onOpen, child: const Text('Test Merkezi')),
          ])))),
      Expanded(child: child),
    ]);
  }
}
