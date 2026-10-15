import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'supabase_scope.dart';

/// Fixed local endpoint only. Never accepts a cloud/staging/production URL.
bool isLocalTestBackend(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'http' &&
      uri.host == '127.0.0.1' &&
      uri.port == 55421 &&
      uri.userInfo.isEmpty &&
      (uri.path.isEmpty || uri.path == '/') &&
      !uri.hasQuery && !uri.hasFragment;
}

enum LocalTestPersona { viewer, manager, coach, athlete, accountant }

extension LocalTestPersonaAccount on LocalTestPersona {
  String get email => switch (this) {
        LocalTestPersona.viewer => 'taraftar@test.swansport.invalid',
        LocalTestPersona.manager => 'kulup-yoneticisi@test.swansport.invalid',
        LocalTestPersona.coach => 'antrenor-3@test.swansport.invalid',
        LocalTestPersona.athlete => 'lisansli-sporcu@test.swansport.invalid',
        LocalTestPersona.accountant => 'muhasebeci@test.swansport.invalid',
      };
}

/// Real Auth sessions; no SwanAccess override or synthetic JWT.
class LocalTestAccountService {
  LocalTestAccountService(this._backendUrl, this._session);
  final String _backendUrl;
  final AccountSessionService _session;
  bool _busy = false;

  Future<void> switchTo(LocalTestPersona persona) async {
    if (!isLocalTestBackend(_backendUrl)) {
      throw StateError('Test hesapları yalnız yerel test backend ile kullanılabilir.');
    }
    if (_busy) throw StateError('Hesap değişimi sürüyor.');
    _busy = true;
    try {
      // Drop the previous session first; a failed login never leaves that role active.
      await _session.signOut();
      await _session.signIn(email: persona.email, password: 'test1234');
    } finally {
      _busy = false;
    }
  }
}

final localTestAccountServiceProvider = Provider<LocalTestAccountService>((ref) {
  final url = ref.watch(supabaseConfigProvider).url;
  if (!isLocalTestBackend(url)) throw StateError('Yerel test backend gerekli.');
  return LocalTestAccountService(url, ref.watch(accountSessionServiceProvider));
});
