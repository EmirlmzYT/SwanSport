import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/athletes/athlete_detail_screen.dart';
import '../features/auth/console_login_screen.dart';
import 'modules/console_module.dart';
import 'modules/module_registry.dart';
import 'shell/console_shell.dart';
import 'theme/console_theme.dart';

/// Supabase oturum değişikliklerini go_router'a duyurur.
///
/// Giriş/çıkış olduğunda yönlendirme kendiliğinden yeniden değerlendirilsin
/// diye; aksi halde giriş yaptıktan sonra ekran login'de kalırdı.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable() {
    _sub = Supabase.instance.client.auth.onAuthStateChange
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final consoleRouterProvider = Provider<GoRouter>((ref) {
  final auth = _AuthListenable();
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: auth,
    redirect: (context, state) {
      final signedIn = Supabase.instance.client.auth.currentSession != null;
      final atLogin = state.matchedLocation == '/giris';

      if (!signedIn) return atLogin ? null : '/giris';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/giris',
        builder: (_, __) => const ConsoleLoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            ConsoleShell(route: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const _ConsoleHome()),
          for (final m in kConsoleModules)
            GoRoute(
              path: m.route,
              builder: (context, __) => _Guarded(module: m),
            ),
          // Modül listesinde yer almayan alt sayfalar (kenar çubuğunda görünmez
          // ama kendi başlarına adreslenebilir olmaları gerekir).
          GoRoute(
            path: '/sporcular/:id',
            builder: (context, state) => _GuardedChild(
              audience: ConsoleAudience.clubStaff,
              label: 'Sporcular',
              child: AthleteDetailScreen(
                athleteId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _NotFound(location: state.uri.path),
  );
});

/// Modülü yalnızca yetkisi olana açar.
///
/// Kenar çubuğunda gizlemek yetmez — kullanıcı adresi doğrudan yazabilir.
/// Bu da nihai koruma değil; veriyi RLS koruyor. Buradaki kontrol, yetkisi
/// olmayana boş tablo yerine anlaşılır bir cümle göstermek için.
class _Guarded extends ConsumerWidget {
  const _Guarded({required this.module});

  final ConsoleModule module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(consoleAccessProvider);
    if (!module.visibleTo(access)) {
      return _NoAccess(label: module.label);
    }
    return module.builder(context);
  }
}

/// Modül listesinde yer almayan alt sayfalar için aynı yetki kontrolü.
class _GuardedChild extends ConsumerWidget {
  const _GuardedChild({
    required this.audience,
    required this.label,
    required this.child,
  });

  final ConsoleAudience audience;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(consoleAccessProvider);
    if (!access.allows(audience)) return _NoAccess(label: label);
    return child;
  }
}

class _ConsoleHome extends ConsumerWidget {
  const _ConsoleHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(consoleAccessProvider);
    final visible = kConsoleModules.where((m) => m.visibleTo(access)).toList();
    final t = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SwanSport Konsol', style: t.textTheme.titleLarge),
            const SizedBox(height: ConsoleDensity.sm),
            Text(
              visible.isEmpty
                  ? 'Bu hesabın yönetebileceği bir alan görünmüyor. Kulüp '
                      'yetkilisi ya da platform yöneticisi olman gerekiyor.'
                  : 'Soldaki menüden bir modül seç.',
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 28, color: t.colorScheme.outline),
            const SizedBox(height: ConsoleDensity.md),
            Text('$label sana kapalı', style: t.textTheme.titleMedium),
            const SizedBox(height: ConsoleDensity.sm),
            Text(
              'Bu modül için gereken yetki hesabında yok. Yanlış olduğunu '
              'düşünüyorsan kulüp yöneticinle görüş.',
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sayfa bulunamadı', style: t.textTheme.titleLarge),
            const SizedBox(height: ConsoleDensity.sm),
            Text(location, style: t.textTheme.bodySmall),
            const SizedBox(height: ConsoleDensity.lg),
            FilledButton(
              onPressed: () => GoRouter.of(context).go('/'),
              child: const Text('Konsola dön'),
            ),
          ],
        ),
      ),
    );
  }
}
