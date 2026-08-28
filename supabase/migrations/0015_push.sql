-- =============================================================================
-- SwanSport — PUSH BİLDİRİMLERİ
--   1) Cihaz abonelikleri tablosu
--   2) `notifications` tablosuna düşen her satır için push gönderimi
--
-- Nasıl çalışır: uygulama tarayıcıdan bir "abonelik" alır ve buraya yazar.
-- Yeni bildirim oluştuğunda tetikleyici, o kişinin tüm abonelikleriyle birlikte
-- Cloudflare'deki /api/push adresine POST atar; şifreleme ve imzalama orada
-- yapılır (özel anahtar veritabanında tutulmaz).
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- pg_net: veritabanından dışarı HTTP isteği atabilmek için.
create extension if not exists pg_net;


-- ---------------------------------------------------------------------------
-- 1) ABONELİKLER
-- ---------------------------------------------------------------------------
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  endpoint    text not null unique,     -- push servisinin verdiği adres
  p256dh      text not null,            -- cihazın açık anahtarı
  auth        text not null,            -- cihazın şifreleme sırrı
  user_agent  text,
  created_at  timestamptz not null default now()
);
create index if not exists idx_push_profile
  on public.push_subscriptions (profile_id);

alter table public.push_subscriptions enable row level security;

-- Kişi yalnızca kendi cihazlarını görür ve yönetir.
drop policy if exists "push_own" on public.push_subscriptions;
create policy "push_own" on public.push_subscriptions for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());


-- ---------------------------------------------------------------------------
-- 2) GÖNDERİM TETİKLEYİCİSİ
-- ---------------------------------------------------------------------------
-- Bildirimin türüne göre uygulama içinde açılacak sayfa.
create or replace function public.push_route(p_kind text, p_entity text)
returns text language sql immutable as $$
  select case p_kind
    when 'message'     then '/mesajlar'
    when 'application' then '/basvurular'
    when 'offer'       then '/bildirimler'
    when 'follow'      then '/bildirimler'
    else '/bildirimler'
  end;
$$;

create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_subs jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
           'endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth)), '[]'::jsonb)
    into v_subs
    from public.push_subscriptions s
   where s.profile_id = new.profile_id;

  -- Abone cihaz yoksa boşuna istek atma.
  if jsonb_array_length(v_subs) = 0 then
    return new;
  end if;

  perform net.http_post(
    url     := 'https://swansport.pages.dev/api/push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', '9958f52564494dea1a2234c511d9948ad0a6f113cfaf68e3'),
    body    := jsonb_build_object(
                 'title', new.title,
                 'body',  coalesce(new.body, ''),
                 'url',   public.push_route(new.kind, new.entity_type),
                 'subs',  v_subs)
  );

  return new;
exception
  -- Push gönderimi bildirimin kendisini engellememeli.
  when others then
    return new;
end; $$;

drop trigger if exists trg_push_on_notification on public.notifications;
create trigger trg_push_on_notification
  after insert on public.notifications
  for each row execute function public.push_on_notification();


-- ---------------------------------------------------------------------------
-- 3) Ölü abonelikleri temizleme (istemci 404/410 aldığında çağırır)
-- ---------------------------------------------------------------------------
create or replace function public.drop_push_subscription(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_subscriptions
   where endpoint = p_endpoint and profile_id = auth.uid();
$$;
