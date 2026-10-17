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
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authSessionProvider).when(
          loading: () => const _Blank(),
          // An Auth failure is not evidence of a signed-out session.
          error: (error, _) => Scaffold(body: Center(child: TextButton(
            onPressed: () => ref.invalidate(authSessionProvider),
            child: const Text('Oturumu yeniden kontrol et'),
          ))),
          data: (session) {
            if (session != null) {
              return ref.watch(setupWizardRequiredProvider(session.user.id)).when(
                    loading: () => const _Blank(),
                    error: (_, __) => const FeedScreen(),
                    data: (needsGuide) => needsGuide
                        ? const SetupWizardScreen()
                        : const FeedScreen(),
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

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
}
