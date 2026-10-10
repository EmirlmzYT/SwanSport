set local lock_timeout = '15s';

-- Existing feature and FAQ system; no publication-stage change.
insert into public.faq_entries
  (question, answer, category, audience, feature, route, sort_order)
select v.question, v.answer, 'Antrenman', v.audience,
       'sport_training_sessions', '/antrenman-oturumu', v.sort_order
from (values
  ('Canlı antrenmanda branşıma göre nasıl sonuç girerim?',
   'Oturum şablonu giriş panelini belirler. Hedef puanında halkaları veya sayısal girişi kullan; drill sayacında başarı ve hata say, rallide winner, basit hata veya ace ekle. Ace winner toplamına dahildir. Her set tek drill içerir; farklı drill için sonraki sete geç. Seti kaydet düğmesi sonucu gönderir. Başarısız kayıtta sayaçların korunur, tekrar deneyebilirsin.',
   'everyone', 110),
  ('Tur kronometresini nasıl kullanırım?',
   'Tur aşamasında kronometreyi başlat, mesafeyi metre olarak gir ve tur sonunda TUR AL düğmesine dokun. Her tur bir sete kaydolur; sonraki tur için yeni aşamayı bekle. Arka planda geçen süre ölçüme dahildir; duraklatılan süre dahil değildir. Uygulamayı tamamen kapatmadan önce turunu kaydet: gönderilmemiş kronometre taslağı cihaz belleğindedir. Karnede en iyi tur, ortalama süre ve toplam mesafe görünür.',
   'everyone', 120),
  ('Antrenmanda hızlı geri bildirim nasıl kaydederim?',
   'Kulüp oturumunda hızlı antrenör notu bölümünden katılan sporcuyu seç. Teknik İyi, Duruş Bozuk, Erken Bıraktı, Mükemmel Açı veya Hızlan etiketine dokunmak notu hemen kaydeder. İstersen özel not yazıp Notu kaydet düğmesine dokun. Kayıt başarısızsa uyarıyı görürsün ve metnin korunur. Bireysel oturumlarda antrenör notu bulunmaz.',
   'coach', 130)
) as v(question, answer, audience, sort_order)
where not exists (select 1 from public.faq_entries f where f.question = v.question);
