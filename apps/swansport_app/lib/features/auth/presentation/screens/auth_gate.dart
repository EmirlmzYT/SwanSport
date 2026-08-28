import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../social/presentation/feed_screen.dart';
import 'auth_screen.dart';

/// Uygulama açılış kapısı — "beni hatırla".
///
/// Supabase oturumu tarayıcıda (localStorage) kalıcı saklanır. Açılışta aktif
/// bir oturum varsa doğrudan ana sayfaya (akış) gider, yoksa giriş ekranını
/// gösterir. Ana sayfa herkes için aynıdır; rol yalnızca selamlamayı değiştirir.
/// Çıkış yapılınca `/` rotasına dönülür ve bu kapı yeniden giriş ekranını gösterir.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(isSupabaseEnabledProvider);
    if (enabled &&
        Supabase.instance.client.auth.currentSession != null) {
      return const FeedScreen();
    }
    return const AuthScreen();
  }
}
