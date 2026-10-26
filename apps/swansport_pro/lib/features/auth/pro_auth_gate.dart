import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../workspaces/pro_workspace_controller.dart';
import 'pro_auth_controller.dart';
import 'pro_login_screen.dart';

class ProAuthGate extends ConsumerWidget {
  const ProAuthGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<String?>(
      authSessionProvider.select((value) => value.valueOrNull?.user.id),
      (previousUserId, nextUserId) {
        if (previousUserId != nextUserId) {
          ref.invalidateSwanAccess();
        }
      },
    );
    final sessionAsync = ref.watch(authSessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: Color(0xFFEF4444)),
                const SizedBox(height: 16),
                Text(
                  'Oturum hatası: $error',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => ref.refresh(authSessionProvider),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (session) {
        if (session == null) {
          return const ProLoginScreen();
        }

        final accessReadiness = ref.watch(proAccessReadinessProvider);
        if (accessReadiness.isLoading) {
          return const _ProLoadingScreen();
        }
        if (accessReadiness.hasError) {
          return _ProAccessErrorScreen(
            error: accessReadiness.error!,
            onRetry: ref.invalidateSwanAccess,
          );
        }

        final availableWorkspaces = ref.watch(availableProWorkspacesProvider);

        if (availableWorkspaces.isEmpty) {
          return _NoProAccessScreen(
            userEmail: session.user.email,
            onSignOut: () {
              ref.read(proAuthControllerProvider.notifier).signOut();
            },
          );
        }

        return KeyedSubtree(
          key: ValueKey(session.user.id),
          child: child,
        );
      },
    );
  }
}

class _ProLoadingScreen extends StatelessWidget {
  const _ProLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
    );
  }
}

class _ProAccessErrorScreen extends StatelessWidget {
  const _ProAccessErrorScreen({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profesyonel yetkiler yüklenemedi.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: const TextStyle(color: Color(0xFF94A3B8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onRetry,
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoProAccessScreen extends StatelessWidget {
  const _NoProAccessScreen({
    this.userEmail,
    required this.onSignOut,
  });

  final String? userEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_person_outlined,
                    size: 64,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Profesyonel Erişim Bulunamadı',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'SwanSport Pro için profesyonel yetki bulunamadı. Kulüp yöneticisi, antrenör, federasyon yetkilisi veya hakem hesabı ile giriş yapmalısınız.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (userEmail != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        userEmail!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Çıkış Yap'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
