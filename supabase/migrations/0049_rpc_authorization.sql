-- 0049 — GÜVENLİK: security definer RPC'lere yetki kontrolü
--
-- Faz 0'ın "muhasebeci gizliliği yeni tablo ve RPC'lerden etkilenmiş mi"
-- maddesi denetlendi ve **üç açık bulundu**. Üçü de bu oturumda 0044-0047
-- arasında eklendi.
--
-- `security definer` fonksiyonlar RLS'i **atlar**. Tablolardaki politikalar ne
-- kadar doğru olursa olsun, kontrolsüz bir definer fonksiyonu onların
-- üstünden geçiyor. Üç fonksiyon da gövdesinde hiçbir kontrol yapmadan
-- `authenticated` rolüne açıktı:
--
--   athlete_card(uuid)   -> giriş yapmış herkes, herhangi bir sporcunun
--                           katılım oranını, hedeflerini, başarılarını,
--                           kulübünü ve takımını okuyabiliyordu.
--   event_roster(uuid)   -> herhangi bir etkinliğin tam kadrosu; ad ad,
--                           RSVP ve yoklama durumlarıyla birlikte.
--   event_audience(uuid) -> bir etkinliğin ilgili kişilerinin profil
--                           kimlikleri.
--
-- Kimlik bilmek yetiyordu; uuid tahmin edilemez ama paylaşılan bir ekrandan,
-- bir bağlantıdan ya da başka bir yanıttan sızabilir. Erişim kontrolünü
-- "kimliği bilmiyor" varsayımına dayandırmak kontrol değildir.

-- ---------------------------------------------------------------------------
-- 1) Sporcu kartı — sporcunun kendisi, velisi ve kulüp görevlisi
--
-- Muhasebeci `is_club_staff` kapsamında DEĞİL (0030'da ayrı bir rol olarak
-- kuruldu), yani sporcunun performans ve katılım verisine erişemiyor. Zaten
-- işi aidat; sportif veri onun görmesi gereken bir şey değil.
-- ---------------------------------------------------------------------------
create or replace function public.athlete_card(p_athlete uuid)
returns table (
  trainings      int,
  attendance_pct int,
  goals_done     int,
  goals_active   int,
  achievements   int,
  last_test      date,
  club_name      text,
  team_name      text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select a.club_id into v_club from public.athletes a where a.id = p_athlete;
  if v_club is null then
    return;   -- olmayan sporcu: boş dön, varlığını da ele verme
  end if;

  if not (
       exists (select 1 from public.athletes a
                where a.id = p_athlete and a.profile_id = auth.uid())
    or public.is_guardian_of(p_athlete)
    or public.is_club_staff(v_club)
  ) then
    raise exception 'Bu sporcunun kartını görme yetkin yok';
  end if;

  return query
  with att as (
    select count(*) as total,
           count(*) filter (where status = 'present') as present
      from public.attendance where athlete_id = p_athlete
  ),
  gl as (
    select count(*) filter (where status = 'done')   as done,
           count(*) filter (where status <> 'done')  as active
      from public.development_goals where athlete_id = p_athlete
  )
  select
    (select present from att)::int,
    (select case when total = 0 then 0
                 else round(100.0 * present / total) end from att)::int,
    (select done from gl)::int,
    (select active from gl)::int,
    (select count(*) from public.athlete_achievements
      where athlete_id = p_athlete)::int,
    (select max(test_date) from public.performance_tests
      where athlete_id = p_athlete),
    (select c.name from public.athletes a
       join public.clubs c on c.id = a.club_id where a.id = p_athlete),
    (select t.name from public.team_memberships tm
       join public.teams t on t.id = tm.team_id
      where tm.athlete_id = p_athlete
      order by tm.created_at desc limit 1);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 2) Etkinlik kadrosu — yalnızca kulüp görevlisi
--
-- Bu bir antrenör aracı: yoklama ekranını dolduruyor. Sporcunun kendi
-- takımının kadrosunu ad ad, kimin geleceğiyle birlikte görmesi gerekmiyor.
-- ---------------------------------------------------------------------------
create or replace function public.event_roster(p_event uuid)
returns table (
  athlete_id uuid,
  full_name  text,
  rsvp       text,
  attendance text
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select e.club_id into v_club from public.events e where e.id = p_event;
  if v_club is null then
    return;
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu etkinliğin kadrosunu görme yetkin yok';
  end if;

  return query
  with ev as (select * from public.events where id = p_event)
  select a.id,
         trim(a.first_name || ' ' || a.last_name),
         r.status::text,
         at.status::text
    from ev
    join public.athletes a on a.club_id = ev.club_id
    left join public.event_rsvps r
           on r.event_id = ev.id and r.athlete_id = a.id
    left join public.attendance at
           on at.event_id = ev.id and at.athlete_id = a.id
   where ev.team_id is null
      or exists (select 1 from public.team_memberships tm
                  where tm.team_id = ev.team_id and tm.athlete_id = a.id)
   order by a.first_name, a.last_name;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 3) Etkinlik hedef kitlesi — dışarıya hiç açılmıyor
--
-- Yalnızca `notify_new_event` tetikleyicisi kullanıyor. Tetikleyici zaten
-- `security definer` olarak çalışıyor ve fonksiyonun sahibi üzerinden
-- çağırıyor; `authenticated` rolüne verilmiş olmasının hiçbir gerekçesi yoktu.
-- ---------------------------------------------------------------------------
revoke execute on function public.event_audience(uuid) from authenticated;

-- İzinler yeniden — `create or replace` gövdeyi değiştiriyor, grant'ları değil,
-- ama açıkça yazmak sonraki okuyucuya durumu gösteriyor.
revoke execute on function public.athlete_card(uuid) from public, anon;
grant  execute on function public.athlete_card(uuid) to authenticated;

revoke execute on function public.event_roster(uuid) from public, anon;
grant  execute on function public.event_roster(uuid) to authenticated;
