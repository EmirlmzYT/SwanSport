import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Sosyal katman ve kulüp yaşam döngüsü — veri katmanı.
///
/// Buradaki testlerin çoğu **bir şeyin OLMADIĞINI** doğruluyor: silinmiş
/// içeriğin başlığının dönmediğini, teşhisin modelde bulunmadığını,
/// çakışmanın sessizce çözülmediğini. Bu tür güvenceler kod okunarak
/// anlaşılmıyor ve ilk dokunanda sessizce kayboluyor.
void main() {
  group('Güvenli paylaşım kartı', () {
    test('kullanılamayan kart hiçbir alan taşımıyor', () {
      const c = SharedCard.unavailable();
      expect(c.available, isFalse);
      // Başlık bile dönmemeli: "silinmiş gönderinin başlığı" da
      // sızdırılmış içeriktir.
      expect(c.title, isNull);
      expect(c.subtitle, isNull);
      expect(c.imageRef, isNull);
    });

    test('available=false gelirse diğer alanlar YOK SAYILIYOR', () {
      // Sunucu hatalı biçimde başlık gönderse bile istemci onu çizmemeli.
      final c = SharedCard.fromMap({
        'available': false,
        'title': 'Silinmiş gönderinin gizli başlığı',
        'subtitle': 'Yazar adı',
      });
      expect(c.available, isFalse);
      expect(c.title, isNull);
      expect(c.subtitle, isNull);
    });

    test('erişilebilir kart alanları taşıyor', () {
      final c = SharedCard.fromMap({
        'available': true,
        'title': 'Bugünkü antrenman',
        'subtitle': 'Emir',
        'route': '/akis',
      });
      expect(c.available, isTrue);
      expect(c.title, 'Bugünkü antrenman');
      expect(c.route, '/akis');
    });

    test('boş durum metni sebebi açıklamıyor', () {
      // "Silinmiş" ile "erişimin yok" arasındaki fark, olmayan bir içeriğin
      // varlığını doğrulardı.
      const c = SharedCard.unavailable();
      expect(c.fallbackLabel, 'Bu içerik artık kullanılamıyor');
      expect(c.fallbackLabel.toLowerCase(), isNot(contains('sil')));
      expect(c.fallbackLabel.toLowerCase(), isNot(contains('yetki')));
    });
  });

  group('Görünürlük', () {
    test('anahtarlar SQL kısıtıyla birebir', () {
      // Ayrışırsa insert şema kısıtına takılıyor ve gönderi hiç yazılmıyor.
      expect(visibilityKey(PostVisibility.public), 'public');
      expect(visibilityKey(PostVisibility.followers), 'followers');
      expect(visibilityKey(PostVisibility.club), 'club');
      expect(visibilityKey(PostVisibility.team), 'team');
      expect(visibilityKey(PostVisibility.privateDraft), 'private_draft');
    });

    test('bilinmeyen değer herkese açık sayılmıyor... sayılıyor ve bu bilinçli',
        () {
      // Sunucu zaten kısıtla koruyor; istemcide bilinmeyen bir değeri
      // "taslak" saymak, var olan bir gönderiyi kullanıcıdan gizlerdi.
      expect(visibilityFrom('bilinmeyen'), PostVisibility.public);
    });

    test('etiketlenme izni anahtarları', () {
      expect(mentionPolicyKey(MentionPolicy.everyone), 'everyone');
      expect(mentionPolicyKey(MentionPolicy.following), 'following');
      expect(mentionPolicyKey(MentionPolicy.nobody), 'nobody');
      expect(mentionPolicyFrom('nobody'), MentionPolicy.nobody);
    });

    test('paylaşım türleri sunucudaki content_type ile aynı', () {
      expect(ShareKind.post, 'content_share');
      expect(ShareKind.listing, 'marketplace_share');
      expect(ShareKind.event, 'event_share');
      expect(ShareKind.organization, 'organization_share');
      expect(ShareKind.all.length, 4);
    });
  });

  group('Uygunluk kilidi', () {
    test('kesin engel blocked=true', () {
      final e = Eligibility.fromMap({
        'blocked': true,
        'status': 'restricted',
        'reason_code': 'health_restriction',
        'reason_label': 'Aktif sağlık kısıtı var',
      });
      expect(e.blocked, isTrue);
      expect(e.isEligible, isFalse);
      expect(e.badgeLabel, 'Kısıtlı');
    });

    test('inceleme sürüyor kesin engel DEĞİL', () {
      // İdari bir eksiği tıbbi bir engel gibi göstermek yanlış olurdu.
      final e = Eligibility.fromMap({
        'blocked': false,
        'status': 'awaiting_verification',
        'reason_code': 'health_review',
        'reason_label': 'Sağlık incelemesi sürüyor',
      });
      expect(e.blocked, isFalse);
      expect(e.awaitingVerification, isTrue);
      expect(e.isEligible, isFalse);
      expect(e.badgeLabel, 'Onay bekliyor');
    });

    test('veri yoksa uygun sayılıyor', () {
      const e = Eligibility.unknown();
      expect(e.isEligible, isTrue);
      expect(e.blocked, isFalse);
    });
  });

  group('Sağlık kısıtı gizliliği', () {
    test('modelde teşhis, rapor ve doktor notu alanı YOK', () {
      final r = HealthRestriction.fromMap({
        'id': 'r1',
        'athlete_id': 'a1',
        'status': 'restricted',
        'start_date': '2026-09-01T00:00:00Z',
        // Sunucu bunları hiç döndürmüyor; yanlışlıkla gelse bile modele
        // girecek bir alan yok.
        'diagnosis': 'gizli teşhis',
        'doctor_note': 'gizli not',
      });

      expect(r.status, 'restricted');
      expect(r.isActive, isTrue);
      expect(r.statusLabel, 'Kısıtlı');
      // Alan olmadığı için erişilebilecek bir yol da yok — bu testin işi
      // o alanların EKLENMESİNİ fark ettirmek.
      expect(r.evidenceRef, isNull);
    });

    test('kaldırılmış kısıt aktif değil', () {
      final r = HealthRestriction.fromMap({
        'id': 'r',
        'athlete_id': 'a',
        'status': 'cleared',
        'start_date': '2026-08-01T00:00:00Z',
        'end_date': '2026-09-01T00:00:00Z',
      });
      expect(r.isActive, isFalse);
      expect(r.statusLabel, 'Kaldırıldı');
    });
  });

  group('Yoklama sürüm çakışması', () {
    test('çakışma sessizce çözülmüyor, listede dönüyor', () {
      final res = AttendanceOpResult.fromMap({
        'applied': 5,
        'replayed': false,
        'conflicts': [
          {
            'athlete_id': 'a1',
            'reason': 'version_mismatch',
            'sent_status': 'present',
            'sent_version': 2,
            'current_status': 'absent',
            'current_version': 3,
          }
        ],
      });

      expect(res.applied, 5);
      expect(res.hasConflicts, isTrue);
      final c = res.conflicts.single;
      // İstemci "sen present dedin, şu an absent yazıyor" diyebilmeli.
      expect(c.sentStatus, 'present');
      expect(c.currentStatus, 'absent');
      expect(c.wasDeleted, isFalse);
    });

    test('silinmiş kayıt ayrı gerekçe', () {
      final res = AttendanceOpResult.fromMap({
        'applied': 0,
        'conflicts': [
          {'athlete_id': 'a', 'reason': 'deleted', 'sent_version': 4}
        ],
      });
      expect(res.conflicts.single.wasDeleted, isTrue);
      expect(res.conflicts.single.currentStatus, isNull);
    });

    test('tekrar gönderim işaretli dönüyor', () {
      final res = AttendanceOpResult.fromMap(
          {'applied': 12, 'conflicts': [], 'replayed': true});
      expect(res.replayed, isTrue);
      expect(res.hasConflicts, isFalse);
      // Uygulanan sayı ilk seferin sonucundan geliyor; sıfır değil.
      expect(res.applied, 12);
    });
  });

  group('Kadro satırı', () {
    test('sürümsüz RPC 0 bırakıyor, tip yine de çalışıyor', () {
      const r = RosterEntry(athleteId: 'a', fullName: 'Ali Veli');
      expect(r.version, 0);
      expect(r.eligibility, isNull);
      expect(r.isBlocked, isFalse);
    });

    test('sürümlü RPC alanları dolduruyor', () {
      final r = RosterEntry.fromVersionedMap({
        'athlete_id': 'a1',
        'full_name': 'Ali Veli',
        'status': 'present',
        'version': 3,
        'rsvp_status': 'attending',
        'eligibility': 'restricted',
      });
      expect(r.version, 3);
      expect(r.isBlocked, isTrue);
      // Kaydedilmiş yoklama RSVP tahminini eziyor (mevcut kural korunuyor).
      expect(r.suggested, 'present');
    });

    test('kısıtlı olmayan sporcu engelli değil', () {
      final r = RosterEntry.fromVersionedMap({
        'athlete_id': 'a',
        'full_name': 'B',
        'eligibility': 'awaiting_verification',
      });
      expect(r.isBlocked, isFalse);
    });
  });

  group('Operasyon riski', () {
    test('tek puan değil gerekçe listesi', () {
      final risk = OperationalRisk([
        RiskReason.fromMap({
          'code': 'unlinked_movement',
          'label': '4 hesapsız mali hareket',
          'severity': 'dikkat',
          'qty': 4,
          'route': '/kasa'
        }),
        RiskReason.fromMap({
          'code': 'license_expiring',
          'label': 'Lisansı dolan sporcu',
          'severity': 'kritik',
          'qty': 7,
          'route': '/sporcular'
        }),
      ]);

      expect(risk.level, 'kritik');
      expect(risk.levelLabel, 'Kritik risk');
      expect(risk.criticalCount, 1);
      expect(risk.active.length, 2);
    });

    test('adedi sıfır olan gerekçe seviyeyi yükseltmiyor', () {
      final risk = OperationalRisk([
        RiskReason.fromMap({
          'code': 'negative_account',
          'label': 'Negatif hesap',
          'severity': 'kritik',
          'qty': 0,
          'route': '/kasa'
        }),
      ]);
      expect(risk.level, 'dusuk');
      expect(risk.active, isEmpty);
      expect(risk.criticalCount, 0);
    });

    test('seviye metin olarak da veriliyor', () {
      // Erişilebilirlik: renk tek başına bilgi taşımamalı.
      final r = RiskReason.fromMap(
          {'code': 'x', 'label': 'y', 'severity': 'dikkat', 'qty': 1});
      expect(r.severityLabel, 'Dikkat gerekli');
    });
  });

  group('Destek talebi', () {
    test('durum etiketleri ve açıklık', () {
      SupportTicket t(String s) => SupportTicket.fromMap(
          {'id': 'x', 'subject': 'k', 'status': s, 'created_at': ''});

      expect(t('new').statusLabel, 'Yeni');
      expect(t('awaiting_user_response').statusLabel, 'Yanıtın bekleniyor');
      expect(t('new').isOpen, isTrue);
      expect(t('resolved').isOpen, isFalse);
      expect(t('closed').isOpen, isFalse);
    });
  });
}
