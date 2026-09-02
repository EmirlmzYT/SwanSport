import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının açık/koyu tema tercihi.
///
/// **Neden sunucuda değil cihazda:** aynı kişi tablette gündüz açık,
/// telefonda gece koyu isteyebilir. Tercihi hesaba bağlamak bu ikisini
/// birbirine zincirlerdi. `shared_preferences` zaten bağımlılık
/// (`update_gate.dart`).
///
/// **Varsayılan `system`:** uygulama bugün de telefonun ayarını izliyordu
/// (`MaterialApp`'te `themeMode` hiç verilmemişti). Varsayılanı değiştirmek,
/// hiçbir tercih yapmamış herkesin temasını bir güncellemede değiştirirdi.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system) {
    _load();
  }

  static const _key = 'swansport.theme_mode';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = _decode(prefs.getString(_key));
    } catch (_) {
      // Okuma başarısızsa sistem temasında kalıyor. Tema tercihi yüzünden
      // açılış kırılmamalı.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, _encode(mode));
    } catch (_) {
      // Yazma başarısızsa ekranda seçim duruyor ama kalıcı olmuyor.
      // Kullanıcıya hata göstermek, yapabileceği bir şey olmadığı için
      // yalnızca rahatsız ederdi.
    }
  }

  static String _encode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  /// Bilinmeyen değer `system`'e düşüyor — eski ya da bozuk bir kayıt
  /// uygulamayı kırmamalı.
  static ThemeMode _decode(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  /// Test ve arayüz için: kodlama gidiş-dönüşü tek yerde.
  @visibleForTesting
  static String encode(ThemeMode m) => _encode(m);

  @visibleForTesting
  static ThemeMode decode(String? v) => _decode(v);
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
        (ref) => ThemeModeController());

String themeModeLabel(ThemeMode m) => switch (m) {
      ThemeMode.light => 'Açık',
      ThemeMode.dark => 'Koyu',
      ThemeMode.system => 'Telefonla aynı',
    };
