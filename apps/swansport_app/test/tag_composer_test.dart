import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/widgets/tag_composer.dart';

/// Etiket ayrıştırma.
///
/// Bu mantık sessiz hataya çok açık: yanlış bir sınır kontrolü e-posta
/// adresini etiket sanıyor, eksik bir Türkçe karakter sınıfı "#Işıklar"ı
/// "#I" diye kesiyor. İkisi de çalışıyor görünüp yanlış veri yazıyor.
void main() {
  MentionCandidate cand(String id, String name, [String? username]) =>
      MentionCandidate(profileId: id, fullName: name, username: username);

  group('activeToken — öneri ne zaman açılır', () {
    test('kelime başındaki @ yakalanıyor', () {
      final t = TagState.activeToken('merhaba @emi', 12);
      expect(t, isNotNull);
      expect(t!.sigil, '@');
      expect(t.query, 'emi');
      expect(t.start, 8);
    });

    test('metnin en başındaki @ da yakalanıyor', () {
      final t = TagState.activeToken('@ali', 4);
      expect(t?.sigil, '@');
      expect(t?.query, 'ali');
      expect(t?.start, 0);
    });

    test('e-posta etiket sanılmıyor', () {
      // "ornek@kulup.org" yazan kişiye kişi listesi açmak, hem yanlış hem
      // sinir bozucu.
      expect(TagState.activeToken('ornek@kulup', 11), isNull);
    });

    test('boşluktan sonra öneri kapanıyor', () {
      // "@Emir " yazıp devam edene öneri göstermeye devam etmek, listeyi
      // kapatmak için ayrı bir hareket gerektirirdi.
      expect(TagState.activeToken('@Emir devam', 11), isNull);
    });

    test('# de aynı kurallarla yakalanıyor', () {
      final t = TagState.activeToken('bugün #antren', 13);
      expect(t?.sigil, '#');
      expect(t?.query, 'antren');
    });

    test('imlecin solundaki en son işaret kazanıyor', () {
      final t = TagState.activeToken('@ali ve #kamp', 13);
      expect(t?.sigil, '#');
      expect(t?.query, 'kamp');
    });

    test('boş sorgu da geçerli — takip ettiklerin listelenir', () {
      final t = TagState.activeToken('selam @', 7);
      expect(t?.sigil, '@');
      expect(t?.query, '');
    });

    test('imleç sıfırda ya da aralık dışındaysa null', () {
      expect(TagState.activeToken('@ali', 0), isNull);
      expect(TagState.activeToken('@ali', 99), isNull);
    });
  });

  group('Hashtag ayrıştırma', () {
    test('Türkçe karakterler kesilmiyor', () {
      final tags = TagState.hashtagsIn('#Işıklar #GÜÇ #çalışma');
      // tr_fold uygulanıyor: sunucu da aynısını yapıyor.
      expect(tags, contains(trFold('Işıklar')));
      expect(tags, contains(trFold('GÜÇ')));
      expect(tags, contains(trFold('çalışma')));
      expect(tags.length, 3);
    });

    test('aynı etiket farklı yazımla tek kayda düşüyor', () {
      // "#Işıklar" ve "#isiklar" aynı etiket; ayrışsalardı arama ikiye
      // bölünürdü.
      final tags = TagState.hashtagsIn('#Işıklar ve #isiklar');
      expect(tags.length, 1);
    });

    test('kelime içindeki # etiket değil', () {
      expect(TagState.hashtagsIn('renk#123 kodu'), isEmpty);
    });

    test('etiketsiz metin boş liste veriyor', () {
      expect(TagState.hashtagsIn('düz bir cümle'), isEmpty);
    });

    test('noktalama etiketi bitiriyor', () {
      final tags = TagState.hashtagsIn('harika #kamp, bitti.');
      expect(tags, [trFold('kamp')]);
    });
  });

  group('Seçilen kişiler metne bağlı', () {
    test('metinde duran etiket gönderiliyor', () {
      final st = TagState()..pick(cand('u1', 'Emir Yılmaz', 'emir'));
      expect(st.mentionsIn('selam @emir'), ['u1']);
    });

    test('metinden silinen etiket GÖNDERİLMİYOR', () {
      // Metinde görünmeyen bir etiketi göndermek, kullanıcının görmediği
      // bir bildirim üretmek olurdu.
      final st = TagState()..pick(cand('u1', 'Emir Yılmaz', 'emir'));
      expect(st.mentionsIn('selam'), isEmpty);
      expect(st.droppedIn('selam'), 1);
    });

    test('aynı kişi iki kez yazılsa da bir kez gönderiliyor', () {
      final st = TagState()..pick(cand('u1', 'Emir', 'emir'));
      expect(st.mentionsIn('@emir ve yine @emir'), ['u1']);
    });

    test('kullanıcı adı yoksa tam ad kullanılıyor', () {
      final st = TagState()..pick(cand('u2', 'Ayşe Kaya'));
      expect(st.mentionsIn('@Ayşe Kaya geldi'), ['u2']);
    });

    test('hiç seçim yoksa düşen de yok', () {
      expect(TagState().droppedIn('@kimse'), 0);
      expect(TagState().mentionsIn('@kimse'), isEmpty);
    });
  });

  group('MentionCandidate', () {
    test('handle kullanıcı adını tercih ediyor', () {
      expect(cand('u', 'Emir Yılmaz', 'emir').handle, 'emir');
      expect(cand('u', 'Emir Yılmaz').handle, 'Emir Yılmaz');
      // Boş kullanıcı adı da tam ada düşmeli.
      expect(cand('u', 'Emir Yılmaz', '').handle, 'Emir Yılmaz');
    });

    test('baş harfler iki kelimeden', () {
      expect(cand('u', 'Emir Yılmaz').initials, 'EY');
      expect(cand('u', 'Emir').initials, 'E');
    });
  });
}
