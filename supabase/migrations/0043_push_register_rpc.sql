-- 0043 — Cihaz kaydı: aynı telefonda hesap değişince de çalışsın
--
-- SORUN: bildirim aç/kapa anahtarı `42501` (RLS ihlali) veriyordu ve cihaz
-- hiç kaydedilmediği için bildirim de gelmiyordu. İki belirti tek hata.
--
-- SEBEP: uygulama doğrudan `upsert(..., onConflict: 'endpoint')` çağırıyordu.
-- `endpoint` tabloda **globalde tekil**; politika ise:
--
--     using (profile_id = auth.uid())
--
-- Postgres `ON CONFLICT DO UPDATE`'te `USING`'i **mevcut satıra** uyguluyor.
-- Aynı cihazın adresi daha önce başka bir hesapla kaydedildiyse yeni hesap o
-- satıra dokunamıyor ve insert `42501` ile düşüyor. Aynı telefonda iki
-- hesapla test etmek bunu tetiklemeye yetiyor.
--
-- ÇÖZÜM: kaydı `security definer` bir fonksiyona taşımak — `drop_push_
-- subscription` (0015) zaten aynı desende. Fonksiyon adresi **o an giriş
-- yapmış kişiye devrediyor**.
--
-- Devretmek doğru davranış, geçici bir çözüm değil: FCM token'ı uygulama
-- kurulumuna ait, kullanıcıya değil. Telefonda hesap değişince o cihaza
-- gidecek bildirimler de yeni hesabın olmalı. Devretmezsek telefon eski
-- hesabın bildirimlerini almaya devam ederdi — daha kötüsü bu.
--
-- Bunun bilinen bedeli: birinin cihaz adresini ele geçiren biri, kimlik
-- doğrulamış olmak kaydıyla o cihaza kendi bildirimlerinin gitmesini
-- sağlayabilir. Token gizli sayılmaz ama herkese açık da değil; her mobil
-- uygulamada aynı ödünleşim var ve alternatifi (devretmemek) özelliği
-- tamamen kırıyor.

create or replace function public.register_push_subscription(
  p_endpoint   text,
  p_kind       text default 'fcm',
  p_p256dh     text default null,
  p_auth       text default null,
  p_user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Cihaz kaydı için oturum gerekli';
  end if;

  if coalesce(trim(p_endpoint), '') = '' then
    raise exception 'Cihaz adresi boş olamaz';
  end if;

  insert into public.push_subscriptions
    (profile_id, endpoint, kind, p256dh, auth, user_agent)
  values
    (v_uid, p_endpoint, coalesce(nullif(trim(p_kind), ''), 'fcm'),
     p_p256dh, p_auth, p_user_agent)
  on conflict (endpoint) do update
    set profile_id = v_uid,          -- devir: cihaz artık bu hesaba ait
        kind       = excluded.kind,
        p256dh     = excluded.p256dh,
        auth       = excluded.auth,
        -- Eski user_agent'ı yeni çağrı boş geçtiyse koru; bilgi kaybetme.
        user_agent = coalesce(excluded.user_agent,
                              push_subscriptions.user_agent);
end;
$fn$;

revoke execute on function
  public.register_push_subscription(text, text, text, text, text)
  from public, anon;
grant execute on function
  public.register_push_subscription(text, text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Kayıt kontrolü de fonksiyona taşınıyor.
--
-- Doğrudan `select` RLS yüzünden **başkasına ait bir satırı boş** döndürüyor.
-- Tanılama ekranı bunu "kayıt yok" diye gösteriyordu, oysa satır vardı ve
-- başkasına aitti — yani yanlış teşhis. Bu fonksiyon farkı söylüyor.
-- ---------------------------------------------------------------------------
create or replace function public.push_subscription_state(p_endpoint text)
returns text
language sql
stable
security definer
set search_path = public
as $fn$
  select case
    when auth.uid() is null then 'no_session'
    when not exists (select 1 from public.push_subscriptions
                      where endpoint = p_endpoint) then 'missing'
    when exists (select 1 from public.push_subscriptions
                  where endpoint = p_endpoint and profile_id = auth.uid())
      then 'mine'
    else 'other_account'
  end;
$fn$;

revoke execute on function public.push_subscription_state(text)
  from public, anon;
grant execute on function public.push_subscription_state(text)
  to authenticated;
