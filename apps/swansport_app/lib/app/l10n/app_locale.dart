import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desteklenen diller ve yerel ayar eşleşmeleri.
enum AppLanguage {
  tr(
    code: 'tr',
    title: 'Türkçe',
    nativeName: 'Türkçe',
    flag: '🇹🇷',
    locale: Locale('tr', 'TR'),
  ),
  en(
    code: 'en',
    title: 'English',
    nativeName: 'English',
    flag: '🇬🇧',
    locale: Locale('en', 'US'),
  );

  const AppLanguage({
    required this.code,
    required this.title,
    required this.nativeName,
    required this.flag,
    required this.locale,
  });

  final String code;
  final String title;
  final String nativeName;
  final String flag;
  final Locale locale;

  static const defaultLanguage = AppLanguage.tr;

  static const supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
    Locale('tr'),
    Locale('en'),
  ];

  static AppLanguage fromCode(String? code) {
    if (code == null) return defaultLanguage;
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code.toLowerCase(),
      orElse: () => defaultLanguage,
    );
  }
}

/// Uygulama dil durumu yöneticisi.
class AppLocaleNotifier extends StateNotifier<AppLanguage> {
  AppLocaleNotifier() : super(AppLanguage.defaultLanguage) {
    _loadSavedLanguage();
  }

  static const _prefKey = 'swansport_selected_language';

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) {
        state = AppLanguage.fromCode(code);
      }
    } catch (_) {
      // SharedPreferences başlatılamazsa varsayılan Türkçe devam eder.
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
    } catch (_) {
      // ignore
    }
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, AppLanguage>((ref) {
  return AppLocaleNotifier();
});
