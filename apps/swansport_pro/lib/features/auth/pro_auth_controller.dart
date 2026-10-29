import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/push/pro_push_client.dart';

class ProAuthState {
  const ProAuthState({
    this.isSubmitting = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final String? errorMessage;

  ProAuthState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProAuthState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProAuthController extends StateNotifier<ProAuthState> {
  ProAuthController(
    this._sessionService, {
    Future<void> Function()? beforeSignOut,
  })  : _beforeSignOut = beforeSignOut,
        super(const ProAuthState());

  final AccountSessionService _sessionService;
  final Future<void> Function()? _beforeSignOut;

  Future<bool> signIn(String email, String password) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      state = state.copyWith(errorMessage: 'E-posta adresi boş bırakılamaz.');
      return false;
    }
    if (password.isEmpty) {
      state = state.copyWith(errorMessage: 'Şifre boş bırakılamaz.');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await _sessionService.signIn(email: trimmedEmail, password: password);
      state = state.copyWith(isSubmitting: false, clearError: true);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Giriş yapılırken bir hata oluştu: $e',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = const ProAuthState();
    try {
      await _beforeSignOut?.call();
    } catch (error) {
      debugPrint('Pro push cleanup before sign-out failed: $error');
    } finally {
      await _sessionService.signOut();
    }
  }
}

final proAuthControllerProvider =
    StateNotifierProvider<ProAuthController, ProAuthState>((ref) {
  final sessionService = ref.watch(accountSessionServiceProvider);
  return ProAuthController(
    sessionService,
    beforeSignOut: ref.watch(proPushClientProvider).unregisterFromServer,
  );
});
