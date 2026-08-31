import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';

/// Doğrudan mesaj modeli.
///
/// Buradaki üç şey ekranda sessizce yanlış davranabilir: okundu bilgisi,
/// gönderim durumu ve akıştan gelen aynı mesajın üstüne yazılması. Üçü de
/// gözle bakınca "çalışıyor gibi" görünür.
void main() {
  MessageRow msg(
    String id, {
    bool mine = true,
    DateTime? readAt,
    MessageStatus status = MessageStatus.sent,
    DateTime? at,
  }) =>
      MessageRow(
        id: id,
        body: 'merhaba',
        createdAt: at ?? DateTime(2026, 9, 1, 12),
        isMine: mine,
        readAt: readAt,
        status: status,
      );

  group('okundu bilgisi', () {
    test('read_at doluysa okunmuş sayılır', () {
      expect(msg('a', readAt: DateTime(2026, 9, 1, 12, 5)).isRead, isTrue);
      expect(msg('a').isRead, isFalse);
    });
  });

  group('gönderim durumu', () {
    test('varsayılan gönderilmiş', () {
      // Sunucudan gelen her mesaj zaten gitmiştir; `sending` yalnızca
      // iyimser gönderimdeki yerel kopya için.
      expect(msg('a').status, MessageStatus.sent);
    });

    test('copyWith yalnızca durumu değiştirir', () {
      final read = DateTime(2026, 9, 1, 12, 5);
      final a = msg('a', readAt: read, status: MessageStatus.sending);
      final b = a.copyWith(status: MessageStatus.failed);

      expect(b.status, MessageStatus.failed);
      // Geri kalanı korunmalı: başarısız gönderimi tekrar denerken metni
      // ve id'yi kaybedersek kullanıcı yazdığını kaybeder.
      expect(b.id, a.id);
      expect(b.body, a.body);
      expect(b.createdAt, a.createdAt);
      expect(b.isMine, a.isMine);
      expect(b.readAt, read);
    });

    test('copyWith argümansız çağrılınca durum korunur', () {
      expect(
        msg('a', status: MessageStatus.sending).copyWith().status,
        MessageStatus.sending,
      );
    });
  });

  group('akış birleştirme', () {
    // `chatProvider` geçmişi ve canlı akışı id'ye göre birleştiriyor.
    // Buradaki davranışı sabitliyoruz: aynı id geldiğinde YENİSİ kazanmalı —
    // çift tik böyle çalışıyor, `read_at` güncellenince aynı mesaj yeni
    // hâliyle geliyor.
    List<MessageRow> merge(List<MessageRow> history, List<MessageRow> live) {
      final byId = {for (final m in history) m.id: m};
      for (final m in live) {
        byId[m.id] = m;
      }
      return byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    test('aynı mesaj iki kez gelirse tekilleşir', () {
      final out = merge([msg('a')], [msg('a')]);
      expect(out.length, 1);
    });

    test('akıştan gelen okundu bilgisi geçmişin üstüne yazar', () {
      final read = DateTime(2026, 9, 1, 12, 5);
      final out = merge([msg('a')], [msg('a', readAt: read)]);

      expect(out.single.isRead, isTrue,
          reason: 'yeni hâli kazanmazsa çift tik hiç görünmez');
    });

    test('zamana göre sıralanır', () {
      final out = merge(
        [msg('b', at: DateTime(2026, 9, 1, 12, 30))],
        [msg('a', at: DateTime(2026, 9, 1, 12, 10))],
      );
      expect(out.map((m) => m.id).toList(), ['a', 'b']);
    });
  });

  group('mergeChat — dayanıklılık', () {
    MessageRow m(String id, {DateTime? readAt, DateTime? at}) => MessageRow(
          id: id,
          body: id,
          createdAt: at ?? DateTime(2026, 9, 1, 12),
          isMine: true,
          readAt: readAt,
        );

    test('canlı akış patlarsa geçmiş EKRANDA KALIR', () async {
      // Canlıda kırılan tam olarak buydu: akış kurulamayınca hata yukarı
      // taşınıyor ve sohbet "Veri yüklenemedi" gösteriyordu — oysa geçmiş
      // çoktan yüklenmişti.
      final out = await mergeChat(
        history: () async => [m('a')],
        live: (_) => Stream.error(StateError('realtime yok')),
        // yoklama yok: akış patlayınca sessizce bitmeli, patlamamalı
      ).toList();

      expect(out.length, 1);
      expect(out.single.single.id, 'a');
    });

    test('akış patlayınca yoklamaya düşer ve mesaj gelmeye devam eder',
        () async {
      var polls = 0;
      final out = await mergeChat(
        history: () async => [m('a')],
        live: (_) => Stream.error(StateError('realtime yok')),
        poll: () async {
          polls++;
          return [m('a'), m('b', at: DateTime(2026, 9, 1, 12, 5))];
        },
        pollEvery: const Duration(milliseconds: 5),
      ).take(2).toList();

      expect(polls, greaterThan(0));
      expect(out.last.map((x) => x.id).toList(), ['a', 'b']);
    });

    test('yoklama da hata verirse ekrandaki mesajlar kaybolmaz', () async {
      var n = 0;
      final out = await mergeChat(
        history: () async => [m('a')],
        live: (_) => Stream.error(StateError('yok')),
        poll: () async {
          n++;
          if (n < 3) throw StateError('ağ koptu');
          return [m('a'), m('c', at: DateTime(2026, 9, 1, 12, 9))];
        },
        pollEvery: const Duration(milliseconds: 5),
      ).take(2).toList();

      // İlk iki yoklama patladı ama akış ölmedi; üçüncüsü verdi.
      expect(out.last.map((x) => x.id).toList(), ['a', 'c']);
    });

    test('akış çalışırken okundu bilgisi geçmişin üstüne yazar', () async {
      final read = DateTime(2026, 9, 1, 12, 30);
      final out = await mergeChat(
        history: () async => [m('a')],
        live: (_) => Stream.value([m('a', readAt: read)]),
      ).toList();

      expect(out.last.single.isRead, isTrue,
          reason: 'yeni hâli kazanmazsa çift tik hiç görünmez');
    });

    test('geçmiş yüklenemezse hata TAŞINIR', () async {
      // Bu gerçek bir hata: elinde gösterecek bir şey yok, kullanıcıya
      // söylemek gerekiyor. Yutulacak olan yalnızca canlı akış hatası.
      expect(
        mergeChat(
          history: () async => throw StateError('ağ yok'),
          live: (_) => const Stream.empty(),
        ).toList(),
        throwsStateError,
      );
    });
  });
}
