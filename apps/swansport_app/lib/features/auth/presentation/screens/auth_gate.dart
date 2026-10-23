import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../onboarding/presentation/onboarding_screen.dart';
import '../../../onboarding/application/setup_wizard_progress.dart';
import '../../../onboarding/presentation/setup_wizard_screen.dart';
import '../../../social/presentation/feed_screen.dart';
import '../../../network/presentation/guest_explore_screen.dart';

/// Tanıtımın görülüp görülmediği.
///
/// `FutureProvider` çünkü `shared_preferences` eşzamansız. Kapının kendisi
/// eşzamanlı kalabilirdi ama o zaman tanıtım kararını her açılışta `main`'de
/// vermek gerekirdi; burası daha dar bir yer.
final onboardingSeenProvider = FutureProvider<bool>((ref) => onboardingSeen());

/// Uygulama açılış kapısı — "beni hatırla" ve ilk açılış tanıtımı.
///
/// Supabase oturumu tarayıcıda (localStorage) kalıcı saklanır. Açılışta aktif
/// bir oturum varsa bu cihazda bekleyen yeni kayıt rehberini, yoksa akışı
/// açar. Oturum yoksa **önce
/// tanıtım** gösterilir (bir kez), sonra hesapsız keşif akışı.
///
/// Sıra bilerek böyle: tanıtımın işi uygulamanın ne olduğunu anlatmak, o da
/// kimlik sorulmadan önce anlatılmalı. Oturumu olan kullanıcı tanıtımı hiç
/// görmüyor — ona anlatacak bir şey yok.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, this.onAuthenticatedHomeReady});

  /// Lets Router-based hosts move authenticated users into the persistent
  /// application shell after the setup wizard gate has completed.
  final VoidCallback? onAuthenticatedHomeReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authSessionProvider).when(
          loading: () => const _Blank(),
          // An Auth failure is not evidence of a signed-out session.
          error: (error, _) => SwanScaffold(
              body: Center(
                  child: TextButton(
            onPressed: () => ref.invalidate(authSessionProvider),
            child: const Text('Oturumu yeniden kontrol et'),
          ))),
          data: (session) {
            if (session != null) {
              return ref
                  .watch(setupWizardRequiredProvider(session.user.id))
                  .when(
                    loading: () => const _Blank(),
                    error: (_, __) => onAuthenticatedHomeReady == null
                        ? const FeedScreen()
                        : _OpenAuthenticatedHome(
                            onOpen: onAuthenticatedHomeReady!,
                          ),
                    data: (needsGuide) => needsGuide
                        ? const SetupWizardScreen()
                        : onAuthenticatedHomeReady == null
                            ? const FeedScreen()
                            : _OpenAuthenticatedHome(
                                onOpen: onAuthenticatedHomeReady!,
                              ),
                  );
            }
            return ref.watch(onboardingSeenProvider).when(
                  loading: () => const _Blank(),
                  error: (_, __) => const GuestExploreScreen(),
                  data: (seen) => seen
                      ? const GuestExploreScreen()
                      : OnboardingScreen(
                          onDone: () => ref.invalidate(onboardingSeenProvider)),
                );
          },
        );
  }
}

class _OpenAuthenticatedHome extends StatefulWidget {
  const _OpenAuthenticatedHome({required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<_OpenAuthenticatedHome> createState() => _OpenAuthenticatedHomeState();
}

class _OpenAuthenticatedHomeState extends State<_OpenAuthenticatedHome> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    if (!_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onOpen();
      });
    }
    return const _Blank();
  }
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      SwanScaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
}
