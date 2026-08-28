import 'package:flutter/material.dart';

/// Test kategorilerinin sunum sabitleri — etiket, ikon, renk.
///
/// Bunlar `performance_service.dart` içindeydi; veri katmanı paylaşılan pakete
/// (`swansport_data`) çıkarılırken buraya alındı. Sebebi: `IconData` ve `Color`
/// Flutter arayüz türleridir, veri katmanının UI'a bağlanmaması gerekiyordu.
/// Kategorinin kendisi (`category` alanı) veri; nasıl görüneceği sunum.

/// Test kategorileri. Renkler `dataviz` doğrulayıcısıyla sınanmıştır:
/// açık temada dördü de lightness/chroma/CVD/kontrast kontrollerinden geçer,
/// koyu temada aynı sıradan daha açık basamaklar kullanılır.
const List<({String key, String label, IconData icon})> kTestCategories = [
  (key: 'surat', label: 'Sürat', icon: Icons.bolt_rounded),
  (key: 'dayaniklilik', label: 'Dayanıklılık', icon: Icons.favorite_rounded),
  (key: 'kuvvet', label: 'Kuvvet', icon: Icons.fitness_center_rounded),
  (key: 'teknik', label: 'Teknik', icon: Icons.sports_soccer_rounded),
];

/// Açık tema kategorik palet — tüm kontrollerden geçti.
const Map<String, Color> _catLight = {
  'surat': Color(0xFF009BA6),
  'kuvvet': Color(0xFFC2410C),
  'teknik': Color(0xFF6D45C4),
  'dayaniklilik': Color(0xFF15803D),
};

/// Koyu tema karşılıkları — aynı hue'ların daha açık basamakları.
const Map<String, Color> _catDark = {
  'surat': Color(0xFF14B8B1),
  'kuvvet': Color(0xFFFFB65C),
  'teknik': Color(0xFF9E7BFF),
  'dayaniklilik': Color(0xFF4ADE80),
};

/// Kategori rengi — kimlik rengidir, sıraya göre değişmez.
Color categoryColor(String key, bool isDark) =>
    (isDark ? _catDark : _catLight)[key] ?? (isDark ? _catDark : _catLight)['surat']!;

String categoryLabel(String key) {
  for (final c in kTestCategories) {
    if (c.key == key) return c.label;
  }
  return 'Diğer';
}

IconData categoryIcon(String key) {
  for (final c in kTestCategories) {
    if (c.key == key) return c.icon;
  }
  return Icons.analytics_rounded;
}
