# Resmi müsabaka protokolleri

`validateMatchProtocol(sportCode, raw)` tipli ve değişmez bir
`OfficialMatchProtocol` alt modeli döndürür. Geçersiz girdide ilk hatanın alan
yolunu taşıyan `ProtocolValidationException.errors` okunur. Yerel doğrulama
federasyon yetkisi, lisans kontrolü veya sunucu onayı yerine geçmez.

Paket saf Dart'tır. Flutter/Supabase/runtime bağımlılığı eklenmedi.
`BranchDefinitionContract` ve okçuluk antrenman sözleşmesi korunur. Yeni branşlar
`branchByCode` ile bulunur; kendi `validateProtocol` metotları da vardır.

## Ortak alanlar

- `status`: zorunlu `in_progress` veya `finished`.
- `sport_code`: isteğe bağlı; verilirse fonksiyonun branşıyla aynı olmalı.
- Skorlar `{home: int, away: int}` biçiminde, negatif olmayan tamsayılardır.
  Metin, boolean, kesirli sayı, NaN/Infinity ve JSON güvenli tamsayı sınırını
  aşan sayı reddedilir. Eksik skor sıfır yapılmaz. Toplam da aynı sınırdadır.
- İsteğe bağlı listeler yok/null ise boş; boolean bayraklar yok/null ise false.
  Yanlış tipler varsayılana dönüştürülmez. Bilinmeyen anahtarlar modele taşınmaz.
- Bitmemiş maçta kazanan ilan edilmez. Race modelinde `winners` seri birincilerini
  listeler; diğerlerinde `winner` ev/deplasman/beraberlik/belirsiz enum'udur.

## Basketbol (`basketbol`)

```dart
final result = validateMatchProtocol('basketbol', {
  'status': 'finished',
  'periods': [
    for (var q = 1; q <= 4; q++)
      {'label': 'Q$q', 'home': 20, 'away': 18,
       'team_fouls': {'home': 3, 'away': 4}},
  ],
  'players': [
    {'player_ref': 'internal-player-ref', 'team': 'home',
     'points': 25, 'rebounds': 8, 'assists': 6, 'fouls': 4},
  ],
}) as BasketballMatchProtocol;
// result.score.home == 80; result.winner == MatchWinner.home
```

Q1–Q4 sıralıdır. Sonrasında yalnız önceki toplam eşitse OT1, OT2… gelir.
Bitmiş resmi maç berabere olamaz. Her periyodun `team_fouls` alanı zorunludur;
bu girilen periyot faul sayısıdır, faul cezası/oyuncu çıkarma motoru değildir.
`players` isteğe bağlı, kısmi istatistiktir. Oyuncu ref'i tekrarlanamaz; girilmiş
oyuncu sayıları takım toplamını aşamaz. Tam kadro istenmez.

## Futbol (`futbol`)

`halves`: bir veya iki skor nesnesi; bitmiş maçta iki. `extra_time`: isteğe bağlı
uzatma devreleri; bitmiş uzatmada iki. `knockout: true` eleme formatıdır.
Uzatma yalnız iki normal devre berabereyse mümkündür. Lig maçı berabere bitebilir.

`penalties`: sırayla `{team: 'home'|'away', scored: bool}` atışları. Her iki taraf
başlayabilir. İlk beş atışta matematiksel erken sonuç, sonra eşit atış sayısında
ani ölüm uygulanır. Sonuçlanan seriden sonra atış eklenemez. Eleme beraberliği
bitmiş sayılmak için sonuçlanmış seri ister. Doğrudan penaltı formatı da desteklenir.
Seri golleri `penaltyScore` alanındadır; maç `score` toplamına eklenmez.

`goals` / `cards` isteğe bağlı, kısmi olay listeleridir. Her olayda `minute`,
`player_ref`, `team`; kartta ayrıca `card: 'yellow'|'red'` gerekir.
`added_time` isteğe bağlı tamsayıdır (45+3 => minute=45, added_time=3).
Olay sayısı skoru aşamaz; olay takım alanı golün yazıldığı taraftır (kendi kalesine
golde de). Kadro, oyuncu uygunluğu, ikinci sarının ihraca dönüşmesi hesaplanmaz.

## Tenis (`tenis`)

`best_of`: 3 veya 5; iki/üç set kazanmak gerekir. `sets`: sıralı oyun skorları.
Standart tie-break setleri: 6-0…6-4, 7-5, 7-6. 7-6 için `tie_break` skor nesnesi
zorunludur. `tie_break_target` yoksa 7, ayrıca 10 desteklenir; iki puan fark gerekir.
6-6'da devam eden tie-break kaydedilebilir. Sonuçlanan tie-break'e ek puan,
kazanılan maça ek set veya ara konumda bitmemiş set kabul edilmez.

Devam eden normal oyun için `game_score: {home: '40', away: 'AD'}` verilebilir.
Değerler metin olarak 0/15/30/40/AD; AD yalnız karşısı 40 iken geçerlidir.
Tie-break, bitmiş set veya bitmiş maçta normal oyun puanı bulunmaz.
Avantaj seti, kısa set, no-ad, walkover/retirement ve set yerine oynanan match
tie-break bu sürümün formatları değildir; sessizce standart skora çevrilmez.

## Yüzme / atletizm (`yuzme`, `atletizm`)

`performances`: `{athlete_ref, lane, heat, time_ms, rank, dq, dnf}` kayıtları.
Kulvar/seri 1'den başlar; aynı seride kulvar veya sporcu tekrarlanamaz.
`time_ms` pozitif tamsayı veya `time: '01:02.34'` / `'01:02.345'` biçimi kullanılabilir.
İkisi verilirse aynı derece olmalı. `parseOfficialTime` / `formatOfficialTime`
salise ve milisaniyeyi kayan nokta kullanmadan dönüştürür.

Bitmiş yarışta bitirene derece ve rank zorunlu; DQ/DNF satırında ikisi de yoktur.
DQ ve DNF birlikte olamaz. Rank seri içinde 1,2,3 veya beraberlikte 1,1,3'tür.
Farklı seriler bağımsızdır. Daha yavaş derece daha iyi/eşit rank alamaz.
Yüzmede eşit resmi derece eşit rank; atletizmde foto-finiş kararı aynı yayımlanan
dereceyi farklı rank ile ayırabilir. Bu yüzden atletizmde rank otomatik üretilmez.
Kronometre, resmi yuvarlama, rüzgâr, rekor onayı, atma/atlama veya genel seri
elemesi hesaplanmaz; hakem tarafından verilmiş resmi derece modellenir.

## Veri bağlantısı ve kaynaklar

Bu zengin yerel JSON sözleşmesi mevcut SQL `score/sets/time/rank` allowlist'inin
yerine geçirilmedi. Resmi kayıt RPC'sine bağlanacak katman ayrıca izin verilen
alanlara dönüşüm yapmalıdır; sporcu ref'lerini public sonuçlara doğrudan vermemelidir.
Bu görevde migration, veri erişim grant'i veya yeni ekran yoktur.

Kuralların kapsamı için incelenen resmi kaynaklar:

- [FIBA Official Basketball Rules](https://refereeing.fiba.basketball/en/rules)
- [IFAB Law 10](https://www.theifab.com/laws/latest/determining-the-outcome-of-a-match/)
- [ITF skor ve tie-break açıklamaları](https://www.itftennis.com/en/about-us/organisation/tennis-glossary/)
- [World Aquatics Competition Regulations](https://www.worldaquatics.com/news/3090417/competition-regulations)
- [World Athletics Book of Rules](https://worldathletics.org/about-iaaf/documents/book-of-rules)
