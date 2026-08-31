import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../onboarding/presentation/onboarding_screen.dart';
import '../../../social/presentation/feed_screen.dart';
import 'auth_screen.dart';

/// Tanıtımın görülüp görülmediği.
///
/// `FutureProvider` çünkü `shared_preferences` eşzamansız. Kapının kendisi
/// eşzamanlı kalabilirdi ama o zaman tanıtım kararını her açılışta `main`'de
/// vermek gerekirdi; burası daha dar bir yer.
final onboardingSeenProvider =
    FutureProvider<bool>((ref) => onboardingSeen());

/// Uygulama açılış kapısı — "beni hatırla" ve ilk açılış tanıtımı.
///
/// Supabase oturumu tarayıcıda (localStorage) kalıcı saklanır. Açılışta aktif
/// bir oturum varsa doğrudan ana sayfaya (akış) gider. Oturum yoksa **önce
/// tanıtım** gösterilir (bir kez), sonra giriş ekranı.
///
/// Sıra bilerek böyle: tanıtımın işi uygulamanın ne olduğunu anlatmak, o da
/// kimlik sorulmadan önce anlatılmalı. Oturumu olan kullanıcı tanıtımı hiç
/// görmüyor — ona anlatacak bir şey yok.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(isSupabaseEnabledProvider);
    if (enabled && Supabase.instance.client.auth.currentSession != null) {
      return const FeedScreen();
    }

    final seen = ref.watch(onboardingSeenProvider);
    return seen.when(
      // Tercih okunurken boş bir zemin: burada bir yükleniyor göstergesi
      // koymak, milisaniyelik bir okuma için ekranı titretiyor.
      loading: () => const _Blank(),
      // Okunamazsa tanıtımı atla — hata yüzünden kullanıcıyı tanıtıma
      // düşürmek, tanıtımı kaçırmaktan kötü.
      error: (_, __) => const AuthScreen(),
      data: (done) => done
          ? const AuthScreen()
          : OnboardingScreen(
              onDone: () => ref.invalidate(onboardingSeenProvider),
            ),
    );
  }
}

class _Blank extends StatelessWidget {
  const _Blank();

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Theme.of(context).scaffoldBackgroundColor);
}
