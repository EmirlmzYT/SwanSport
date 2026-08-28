import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AuthMode { signIn, signUp }

enum AuthStatus { idle, submitting, error }

class AuthState {
  const AuthState({
    this.mode = AuthMode.signIn,
    this.status = AuthStatus.idle,
    this.errorMessage,
  });

  final AuthMode mode;
  final AuthStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == AuthStatus.submitting;

  AuthState copyWith({
    AuthMode? mode,
    AuthStatus? status,
    String? errorMessage,
  }) {
    return AuthState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

/// Drives sign-in / sign-up against Supabase Auth.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._auth) : super(const AuthState());

  final GoTrueClient _auth;

  void toggleMode() {
    state = state.copyWith(
      mode: state.mode == AuthMode.signIn ? AuthMode.signUp : AuthMode.signIn,
      status: AuthStatus.idle,
      errorMessage: null,
    );
  }

  /// Returns true when the user ends up with an active session.
  Future<bool> submit({
    required String email,
    required String password,
    String? fullName,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'E-posta ve şifre gerekli.',
      );
      return false;
    }
    if (state.mode == AuthMode.signUp && password.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Şifre en az 6 karakter olmalı.',
      );
      return false;
    }

    state = state.copyWith(status: AuthStatus.submitting, errorMessage: null);

    try {
      if (state.mode == AuthMode.signUp) {
        final response = await _auth.signUp(
          email: trimmedEmail,
          password: password,
          data: <String, dynamic>{
            if (fullName != null && fullName.trim().isNotEmpty)
              'full_name': fullName.trim(),
          },
        );
        // When email confirmation is enabled the session is null until the
        // user confirms. Surface that clearly instead of failing silently.
        if (response.session == null) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorMessage:
                'Hesap oluşturuldu. E-postana gelen onay bağlantısına tıkla, '
                'sonra giriş yap.',
          );
          return false;
        }
      } else {
        await _auth.signInWithPassword(
          email: trimmedEmail,
          password: password,
        );
      }

      state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
      return _auth.currentSession != null;
    } on AuthException catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyMessage(error.message),
      );
      return false;
    } catch (error) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Beklenmeyen bir hata oluştu: $error',
      );
      return false;
    }
  }

  /// Şifre sıfırlama bağlantısı gönderir.
  ///
  /// Kullanıcı e-postasındaki bağlantıya tıklayınca Supabase oturumu açar ve
  /// uygulamada yeni şifresini belirleyebilir.
  Future<bool> sendPasswordReset(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Önce e-posta adresini yaz.',
      );
      return false;
    }
    state = state.copyWith(status: AuthStatus.submitting, errorMessage: null);
    try {
      await _auth.resetPasswordForEmail(trimmed);
      state = state.copyWith(
        status: AuthStatus.idle,
        errorMessage: 'Sıfırlama bağlantısı $trimmed adresine gönderildi.',
      );
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyMessage(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Gönderilemedi: $e',
      );
      return false;
    }
  }

  /// Oturum açıkken yeni şifre belirler.
  Future<bool> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Şifre en az 6 karakter olmalı.',
      );
      return false;
    }
    state = state.copyWith(status: AuthStatus.submitting, errorMessage: null);
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      state = state.copyWith(status: AuthStatus.idle, errorMessage: null);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: _friendlyMessage(e.message),
      );
      return false;
    }
  }

  Future<void> signOut() => _auth.signOut();

  String _friendlyMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (lower.contains('user already registered')) {
      return 'Bu e-posta zaten kayıtlı. Giriş yapmayı dene.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta henüz onaylanmadı. Gelen kutunu kontrol et.';
    }
    if (lower.contains('rate limit')) {
      return 'Çok fazla deneme yapıldı. E-posta gönderim sınırı doldu — '
          'bir süre bekleyip tekrar dene.';
    }
    if (lower.contains('over_email_send_rate') ||
        lower.contains('for security purposes')) {
      return 'Güvenlik nedeniyle biraz beklemen gerekiyor. '
          'Birkaç dakika sonra tekrar dene.';
    }
    if (lower.contains('password should be')) {
      return 'Şifre çok kısa. En az 6 karakter kullan.';
    }
    if (lower.contains('unable to validate email') ||
        lower.contains('invalid email')) {
      return 'E-posta adresi geçersiz görünüyor.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('clientexception')) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';
    }
    return raw;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(Supabase.instance.client.auth);
});
