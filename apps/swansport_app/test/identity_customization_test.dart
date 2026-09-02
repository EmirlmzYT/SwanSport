import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/design/swan_brand.dart';
import 'package:swansport_app/app/design/swan_palette.dart';
import 'package:swansport_app/app/theme/theme_mode_controller.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

/// Kimlik özelleştirme.
///
/// En kritik iki iddia burada:
///   1. Marka rengi **hiçbir zaman** okunmaz bir yazı üretmiyor.
///   2. Renk seçmemiş mevcut kullanıcıların avatarı **değişmiyor**.
///
/// İkincisi kolay kaçırılır: `avatar_tint`'e varsayılan 0 verilseydi herkesin
/// avatarı bir güncellemede renk değiştirirdi ve bunu kimse hata olarak
/// bildirmezdi.
void main() {
  const light = SwanPalette.light;
  const dark = SwanPalette.dark;

  group('BrandTone — okunabilirlik', () {
    test('her hazır renk için yazı okunabilir', () {
      for (final hex in kBrandSwatches) {
        for (final palette in [light, dark]) {
          final tone = BrandTone.from(hex, palette);
          expect(
            contrastRatio(tone.base.toARGB32(), tone.ink.toARGB32()),
            greaterThanOrEqualTo(kContrastNormal),
            reason: '$hex için yazı okunmuyor',
          );
        }
      }
    });

    test('uç renklerde de tutuyor', () {
      // Açık sarı ve koyu lacivert — planın doğrulama adımındaki iki örnek.
      for (final hex in ['#FFE873', '#0B1D51', '#FFFFFF', '#000000']) {
        final tone = BrandTone.from(hex, light);
        expect(contrastRatio(tone.base.toARGB32(), tone.ink.toARGB32()),
            greaterThanOrEqualTo(kContrastNormal));
      }
    });

    test('renk yoksa temanın accent rengine düşüyor', () {
      final l = BrandTone.from(null, light);
      expect(l.isCustom, isFalse);
      expect(l.base, light.accent);

      final d = BrandTone.from(null, dark);
      expect(d.base, dark.accent);
      // Koyu ve açık temanın accent'i farklı; düşüş temaya duyarlı.
      expect(d.base, isNot(l.base));
    });

    test('geçersiz renk çökertmiyor, accent e düşüyor', () {
      // Şemada check kısıtı var ama eski satır ya da elle yazılmış veri
      // buraya bozuk metin düşürebilir.
      for (final bad in ['kırmızı', '#GGG', '', '#12345', 'rgb(1,2,3)']) {
        final tone = BrandTone.from(bad, light);
        expect(tone.isCustom, isFalse);
        expect(tone.base, light.accent);
      }
    });

    test('geçerli renk isCustom işaretliyor', () {
      final tone = BrandTone.from('#E53935', light);
      expect(tone.isCustom, isTrue);
      expect(tone.base.toARGB32(), 0xFFE53935);
    });

    test('küçük harfli hex de kabul ediliyor', () {
      expect(BrandTone.from('#e53935', light).base.toARGB32(), 0xFFE53935);
    });

    test('yumuşak dolgu saydam — akışta gürültü yapmasın', () {
      final tone = BrandTone.from('#E53935', light);
      expect(tone.soft.a, lessThan(1.0));
      expect(tone.stripe, tone.base);
    });
  });

  group('Avatar tonu — mevcut kullanıcılar etkilenmiyor', () {
    SocialProfile p({int? tint, String name = 'Emir Yılmaz'}) => SocialProfile(
          id: 'u1',
          name: name,
          isClub: false,
          avatarTint: tint,
        );

    test('seçim yoksa BUGÜNKÜ türetme kullanılıyor', () {
      // profile_screen.dart:110'daki eski ifade: name.length % 4
      for (final name in ['Ali', 'Emir Yılmaz', 'A', 'Ayşe Kaya Demir']) {
        expect(p(name: name).effectiveTint, name.length % 4);
      }
    });

    test('seçim varsa o kullanılıyor', () {
      expect(p(tint: 2).effectiveTint, 2);
      expect(p(tint: 0).effectiveTint, 0);
    });

    test('sıfır seçimi ile seçimsizlik karışmıyor', () {
      // `0` geçerli bir seçim; null ile aynı şey değil.
      final chosen = p(tint: 0, name: 'Ali'); // Ali.length % 4 == 3
      expect(chosen.effectiveTint, 0);
      expect(p(name: 'Ali').effectiveTint, 3);
    });
  });

  group('Tema tercihi', () {
    test('kodlama gidiş dönüşü kayıpsız', () {
      for (final m in ThemeMode.values) {
        expect(ThemeModeController.decode(ThemeModeController.encode(m)), m);
      }
    });

    test('bilinmeyen ya da eksik değer sisteme düşüyor', () {
      // Eski ya da bozuk bir kayıt uygulamayı kırmamalı.
      expect(ThemeModeController.decode(null), ThemeMode.system);
      expect(ThemeModeController.decode(''), ThemeMode.system);
      expect(ThemeModeController.decode('auto'), ThemeMode.system);
    });

    test('etiketler Türkçe', () {
      expect(themeModeLabel(ThemeMode.light), 'Açık');
      expect(themeModeLabel(ThemeMode.dark), 'Koyu');
      expect(themeModeLabel(ThemeMode.system), 'Telefonla aynı');
    });
  });

  group('Kulüp bölümleri', () {
    test('varsayılan sıra altı bölüm', () {
      expect(ClubSection.defaults.length, 6);
      expect(ClubSection.defaults.first, ClubSection.about);
    });

    test('anahtarlar SQL kısıtıyla birebir', () {
      // `clubs_sections_check` bu altı değeri kabul ediyor; ayrışırsa
      // kulübün kaydettiği sıra sunucuda reddedilir.
      expect(ClubSection.about, 'about');
      expect(ClubSection.teams, 'teams');
      expect(ClubSection.roster, 'roster');
      expect(ClubSection.achievements, 'achievements');
      expect(ClubSection.announcements, 'announcements');
      expect(ClubSection.contact, 'contact');
    });

    test('etiketler her anahtar için var', () {
      for (final k in ClubSection.defaults) {
        expect(ClubSection.label(k), isNotEmpty);
        expect(ClubSection.label(k), isNot(k));
      }
    });

    test('bilinmeyen anahtar ham hâliyle dönüyor', () {
      expect(ClubSection.label('yeni_bolum'), 'yeni_bolum');
    });

    test('null = varsayılan, boş liste = hiçbiri', () {
      const withNull = ClubIdentity(id: 'c', name: 'K');
      expect(withNull.effectiveSections, ClubSection.defaults);

      const withEmpty = ClubIdentity(id: 'c', name: 'K', sections: []);
      // Boş liste geçerli bir tercih: "hiçbir bölüm gösterme".
      expect(withEmpty.effectiveSections, isEmpty);
    });
  });
}
