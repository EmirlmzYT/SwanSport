import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';

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
  ProAuthController(this._sessionService) : super(const ProAuthState());

  final AccountSessionService _sessionService;

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
    await _sessionService.signOut();
  }
}

final proAuthControllerProvider =
    StateNotifierProvider<ProAuthController, ProAuthState>((ref) {
  final sessionService = ref.watch(accountSessionServiceProvider);
  return ProAuthController(sessionService);
});
