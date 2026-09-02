import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// SSS ve destek.
///
/// En önemli iddia: **`is_staff` istemciden gelmiyor.** Model onu okuyor ama
/// yazma yolu yok — sunucu belirliyor. Aksi halde herhangi biri kendi
/// mesajını "SwanSport ekibi" gibi gösterebilirdi.
void main() {
  group('SSS', () {
    test('alanlar okunuyor, rota isteğe bağlı', () {
      final f = FaqEntry.fromMap({
        'id': 'f1',
        'question': 'Aidatımı ödedim ama borcum duruyor.',
        'answer': 'Ödeme bildirimin onay bekliyor olabilir.',
        'category': 'Aidat',
        'route': '/aidatlarim',
      });
      expect(f.question, startsWith('Aidatımı'));
      expect(f.route, '/aidatlarim');
    });

    test('rota yoksa null — düğme çizilmiyor', () {
      final f = FaqEntry.fromMap(
          {'id': 'f', 'question': 'q', 'answer': 'a', 'category': 'Genel'});
      expect(f.route, isNull);
    });

    test('kategori eksikse Genel', () {
      final f = FaqEntry.fromMap({'id': 'f', 'question': 'q', 'answer': 'a'});
      expect(f.category, 'Genel');
    });
  });

  group('Destek mesajı', () {
    test('is_staff sunucudan okunuyor', () {
      final staff = SupportMessage.fromMap({
        'id': 'm1',
        'body': 'Merhaba, kontrol ettik.',
        'is_staff': true,
        'created_at': '2026-09-02T10:00:00Z',
      });
      expect(staff.isStaff, isTrue);
    });

    test('alan eksikse kullanıcı sayılıyor', () {
      // Yanlış tarafa düşmek gerekiyorsa "ekip" değil "kullanıcı" tarafına
      // düşmeli: birini yanlışlıkla yetkili göstermek, yanlışlıkla
      // kullanıcı göstermekten kötü.
      final m = SupportMessage.fromMap(
          {'id': 'm', 'body': 'x', 'created_at': ''});
      expect(m.isStaff, isFalse);
    });
  });

  group('Destek talebi', () {
    SupportTicket t(String s) => SupportTicket.fromMap(
        {'id': 'x', 'subject': 'k', 'status': s, 'created_at': ''});

    test('durum etiketleri', () {
      expect(t('new').statusLabel, 'Yeni');
      expect(t('under_review').statusLabel, 'İnceleniyor');
      expect(t('awaiting_user_response').statusLabel, 'Yanıtın bekleniyor');
      expect(t('resolved').statusLabel, 'Çözüldü');
      expect(t('closed').statusLabel, 'Kapandı');
    });

    test('açık olma tanımı', () {
      expect(t('new').isOpen, isTrue);
      expect(t('awaiting_user_response').isOpen, isTrue);
      expect(t('resolved').isOpen, isFalse);
      expect(t('closed').isOpen, isFalse);
    });
  });

  group('Destek kuyruğu', () {
    SupportQueueItem q({
      int messages = 0,
      String status = 'new',
      String created = '2026-09-01T10:00:00Z',
    }) =>
        SupportQueueItem.fromMap({
          'ticket_id': 'q1',
          'subject': 'Konu',
          'status': status,
          'requester': 'Emir',
          'message_count': messages,
          'last_activity': created,
          'created_at': created,
        });

    test('hiç yanıtlanmamış açık talep işaretleniyor', () {
      expect(q().unanswered, isTrue);
      expect(q(messages: 1).unanswered, isFalse);
    });

    test('kapanmış talep yanıtsız sayılmıyor', () {
      // Kapanmış bir talebin yanıtsız olması normal; kuyrukta uyarı
      // üretmesi gürültü olurdu.
      expect(q(status: 'closed').unanswered, isFalse);
      expect(q(status: 'resolved').unanswered, isFalse);
    });

    test('yaş gün olarak hesaplanıyor', () {
      final item = q(created: '2026-09-01T10:00:00Z');
      expect(item.ageInDays(DateTime.parse('2026-09-03T11:00:00Z')), 2);
      expect(item.ageInDays(DateTime.parse('2026-09-01T23:00:00Z')), 0);
    });

    test('kulüp adı isteğe bağlı', () {
      expect(q().clubName, isNull);
    });
  });

  group('SSS kapsamı — yardımsız yayın yok', () {
    FaqCoverage c({int entries = 0, String audience = 'admins'}) =>
        FaqCoverage.fromMap({
          'feature': 'marketplace',
          'label': 'Pazaryeri',
          'audience': audience,
          'entry_count': entries,
        });

    test('yayında olma tanımı', () {
      expect(c(audience: 'off').isPublished, isFalse);
      expect(c(audience: 'admins').isPublished, isFalse);
      expect(c(audience: 'testers').isPublished, isTrue);
      expect(c(audience: 'everyone').isPublished, isTrue);
    });

    test('kayıt sayısı okunuyor', () {
      expect(c().entryCount, 0);
      expect(c(entries: 3).entryCount, 3);
    });

    test('eksik alanlar çökertmiyor', () {
      final x = FaqCoverage.fromMap({'feature': 'x'});
      expect(x.entryCount, 0);
      expect(x.audience, 'off');
      expect(x.isPublished, isFalse);
    });
  });

  group('SSS özellik bağı', () {
    test('feature null ise genel soru', () {
      final f = FaqEntry.fromMap(
          {'id': 'f', 'question': 'q', 'answer': 'a', 'category': 'Genel'});
      expect(f.feature, isNull);
    });

    test('feature dolu ise özelliğe bağlı', () {
      final f = FaqEntry.fromMap({
        'id': 'f',
        'question': 'q',
        'answer': 'a',
        'category': 'Pazaryeri',
        'feature': 'marketplace',
      });
      expect(f.feature, 'marketplace');
    });
  });
}
