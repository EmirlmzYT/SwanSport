-- ---------------------------------------------------------------------------
-- 0075 — Antrenman bildirimleri
--
-- 0073 `push_route`'a `training_session` ve `training_result` eşlemelerini
-- ekledi ama **hiçbir yer bu bildirimleri göndermiyordu**. Rota vardı,
-- gönderen yoktu: bildirime dokununca açılacak ekran tanımlıydı, dokunulacak
-- bildirim hiç oluşmuyordu.
--
-- NEDEN TETİKLEYİCİ, RPC'YE EKLEME DEĞİL: `start_training_session` ve
-- `lock_session_results` yüz satırlık gövdeler. `create or replace` ile
-- yeniden yazmak, gövdenin bir parçasını sessizce düşürme riski taşıyor —
-- bu depoda `push_route` altı kez yeniden yazıldı ve bir kez gerçekten üç
-- eşleme kayboldu (0022'ninkiler 0039'da). Tetikleyici mevcut gövdeye hiç
-- dokunmuyor.
--
-- Bildirimin push'a dönüşmesi için ayrı iş YOK: `trg_push_on_notification`
-- (0015) `notifications` tablosuna düşen her satırı kendisi gönderiyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) Oturum başladı
--
-- Kime: oturumun kapsamındaki (takım verildiyse o takımın) aktif sporculardan
-- **giriş profili olanlara**. Küçük yaştaki sporcuların profili olmayabiliyor
-- (`athletes.profile_id` nullable, 0001) — profilsiz sporcuya bildirim
-- gönderilemez, `notifications.profile_id` not null.
--
-- Uygunluk kilidi olanlara GÖNDERİLMİYOR: katılamayacağı bir antrenmana
-- çağırmak, kısıtı ona ikinci kez hatırlatmaktan başka bir şey yapmıyor.
-- Bildirim metninde kısıtın sebebi geçmiyor, yalnızca bildirim hiç gitmiyor.
--
-- Katılım kodu gövdeye konuyor: sahada telefonu eline alan sporcunun kodu
-- ayrıca sorması gerekmiyor. Kod zaten yalnızca kendi kulübünün oturumunda
-- çalışıyor ve altı saatte sönüyor.
-- ---------------------------------------------------------------------------
create or replace function public.notify_training_session_started()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  -- Kişisel antrenmanda bildirim yok: oturumu açan zaten sporcunun kendisi.
  if new.kind <> 'club' then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id, actor_id)
  select a.profile_id,
         'training_session',
         'Antrenman başladı',
         pr.name || case when new.join_code is not null
                         then ' · Katılım kodu: ' || new.join_code
                         else '' end,
         'training_session',
         new.id,
         new.created_by
    from public.athletes a
    cross join (select name from public.training_protocols
                 where id = new.protocol_id) pr
   where a.club_id = new.club_id
     and a.status = 'active'
     and a.profile_id is not null
     -- Takım verildiyse yalnızca o takım.
     and (new.team_id is null
          or exists (select 1 from public.team_memberships tm
                      where tm.athlete_id = a.id
                        and tm.team_id = new.team_id))
     -- Bildirim tercihi: takım kanalını kapatan kişiye gönderilmiyor.
     -- Kayıt yoksa varsayılan açık (`coalesce`).
     and coalesce((select np.team_channel
                     from public.notification_preferences np
                    where np.profile_id = a.profile_id), true)
     -- Uygun olmayan sporcuya çağrı gitmiyor.
     and not coalesce((select g.blocked
                         from public.eligibility_gate(a.id) g), false);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_training_session on public.training_sessions;
create trigger trg_notify_training_session
  after insert on public.training_sessions
  for each row execute function public.notify_training_session_started();

-- ---------------------------------------------------------------------------
-- 2) Sonuçlar onaylandı
--
-- `lock_session_results` oturumu `completed` yapıyor; tetikleyici o geçişi
-- yakalıyor. Fonksiyonun kendisine dokunulmuyor.
--
-- Herkese aynı metin gitmiyor: sporcu **kendi** toplamını görüyor. Geri
-- getiren şey "bir şey oldu" değil, "senin sonucun şu" — ve bu kendi verisi,
-- kimsenin verisi değil. Sıralama ya da başkasının puanı geçmiyor.
--
-- Eksik sonuçta sayı yazılmıyor: "0 puan" demek, girmediği seti kötü
-- geçmiş gibi gösterirdi (0071'deki aynı karar).
-- ---------------------------------------------------------------------------
create or replace function public.notify_training_results_locked()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  -- Yalnızca ilk geçişte. `lock_session_results` iki kez çağrılırsa ikinci
  -- çağrı bildirim üretmiyor.
  if new.status <> 'completed' or old.status = 'completed' then
    return new;
  end if;
  if new.kind <> 'club' then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id, actor_id)
  with per as (
    select t.athlete_id, sum(t.total_score) as total
      from public.training_sets t
     where t.session_id = new.id
     group by t.athlete_id
  )
  select a.profile_id,
         'training_result',
         'Antrenman sonuçların onaylandı',
         pr.name || ' · ' || case
           when per.total is null then 'sonuçların hazır'
           else to_char(per.total, 'FM999999.##') || ' puan'
         end,
         'training_session',
         new.id,
         auth.uid()
    from per
    join public.athletes a on a.id = per.athlete_id
    cross join (select name from public.training_protocols
                 where id = new.protocol_id) pr
   where a.profile_id is not null
     and coalesce((select np.team_channel
                     from public.notification_preferences np
                    where np.profile_id = a.profile_id), true);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_training_results on public.training_sessions;
create trigger trg_notify_training_results
  after update of status on public.training_sessions
  for each row execute function public.notify_training_results_locked();

-- ---------------------------------------------------------------------------
-- 3) İzinler
--
-- 0074'ün dersi: tetikleyici fonksiyonları da listeye giriyor. `returns
-- trigger` oldukları için PostgREST üzerinden çağrılamıyorlar, ama izin
-- `PUBLIC`'ten miras alındığı için yine de açıkça kaldırılıyor. Tetikleyici,
-- tabloya bağlıyken sahibin yetkisiyle çalışmaya devam ediyor.
-- ---------------------------------------------------------------------------
revoke execute on function public.notify_training_session_started()
  from public, anon, authenticated;
revoke execute on function public.notify_training_results_locked()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- NOT — sessiz saatler bilerek uygulanmıyor
--
-- `notification_preferences` içinde `quiet_from`/`quiet_to` var ve bu iki
-- bildirim onlara BAKMIYOR. Sebep: ikisi de o anda olan bir şeyi haber
-- veriyor. "Antrenman başladı" bildirimini iki saat sonra göndermek onu
-- yanlış bilgi yapar ve bu kod tabanında erteleyip sonra gönderecek bir
-- kuyruk yok. `team_channel` kapatılabiliyor — kullanıcının gerçek kontrolü o.
--
-- Veliye bildirim de bu turda YOK. `guardian_only` alanı duruyor ama veli
-- bildirimi ayrı bir karar: çocuğun her antrenman sonucunu veliye anlık
-- göndermek istenir mi, ürün tarafında konuşulmadı.
-- ---------------------------------------------------------------------------
