-- 0046 — Başarılar kazanılsın, elle girilmesin
--
-- Denetimin üçüncü kopuk halkası: `athlete_achievements` yalnızca
-- `athletes`'a bağlıydı ve tamamen elle dolduruluyordu. Elle girilen başarı,
-- kimsenin girmediği başarıdır — sistem sporcunun gerçekten yaptığı hiçbir
-- şeyi tanımıyordu.
--
-- 0044 hedefleri ölçüme bağladı; artık hedefin ne zaman tamamlandığı
-- **veriden** biliniyor. Bu migration o bilgiyi başarıya çeviriyor.
--
-- BİLEREK DAR TUTULDU. Denetimde "aşırı oyunlaştırma yapma" kararı vardı:
-- rozet yağmuru, seri (streak), puan yok. Yalnızca gerçek sportif davranışa
-- karşılık gelen üç şey: hedefi tutturmak, düzenli gelmek, çok gelmek.

-- ---------------------------------------------------------------------------
-- 1) Başarının nereden doğduğu
-- ---------------------------------------------------------------------------
alter table public.athlete_achievements
  add column if not exists source    text,
  add column if not exists source_id uuid;

comment on column public.athlete_achievements.source is
  'Otomatik üretildiyse kaynağı: goal | attendance_10 | attendance_50 | '
  'attendance_rate_90. Elle girilenlerde null.';

-- Aynı başarı iki kez verilmesin.
--
-- `coalesce(source_id::text, '')` gerekiyor: kaynak kimliği olmayan
-- başarılarda (katılım kilometre taşları) `source_id` null ve Postgres'te
-- NULL'lar çakışmadığı için düz bir unique indeks onları tekilleştirmezdi —
-- her yoklamada yeni bir "10 antrenman" rozeti düşerdi.
create unique index if not exists idx_achv_source_unique
  on public.athlete_achievements
     (athlete_id, source, coalesce(source_id::text, ''))
  where source is not null;

-- ---------------------------------------------------------------------------
-- 2) Hedef tamamlanınca başarı
--
-- 0044'teki tetikleyici hedefi `done`'a çekiyor; buradaki onu yakalıyor.
-- Ayrı tutuldu çünkü ikisi farklı soruların cevabı: biri "ilerleme ne oldu",
-- öbürü "bu bir başarı mı".
-- ---------------------------------------------------------------------------
create or replace function public.award_goal_achievement()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.status = 'done' and coalesce(old.status, '') <> 'done' then
    insert into public.athlete_achievements
      (athlete_id, title, category, event_date, note, source, source_id)
    values (
      new.athlete_id,
      new.title,
      'gelisim',
      current_date,
      case when new.test_name is null then null
           else new.test_name || ': ' ||
                coalesce(new.baseline_value::text, '?') || ' → ' ||
                coalesce(new.last_value::text, new.target_value::text, '?')
      end,
      'goal',
      new.id
    )
    on conflict do nothing;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_award_goal_achievement on public.development_goals;
create trigger trg_award_goal_achievement
  after update on public.development_goals
  for each row execute function public.award_goal_achievement();

-- ---------------------------------------------------------------------------
-- 3) Katılım kilometre taşları
--
-- Eşikler düşük tutuldu (10 ve 50): bir sporcunun aylar süren emeğini
-- tanımak için var, sürekli rozet üretmek için değil. Aradaki her sayıda
-- rozet vermek bildirimi gürültüye çevirirdi.
--
-- Oran rozeti en az 20 kayıt istiyor. Üç antrenmanın üçüne de gelen birine
-- "%100 katılım" demek, henüz bir şey söylemeyen bir övgü olurdu.
-- ---------------------------------------------------------------------------
create or replace function public.award_attendance_achievements()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_total   int;
  v_present int;
  v_rate    numeric;
begin
  if new.status <> 'present' then
    return new;
  end if;

  select count(*), count(*) filter (where status = 'present')
    into v_total, v_present
    from public.attendance
   where athlete_id = new.athlete_id;

  if v_present >= 10 then
    insert into public.athlete_achievements
      (athlete_id, title, category, event_date, source)
    values (new.athlete_id, '10 antrenman tamamlandı', 'gelisim',
            current_date, 'attendance_10')
    on conflict do nothing;
  end if;

  if v_present >= 50 then
    insert into public.athlete_achievements
      (athlete_id, title, category, event_date, source)
    values (new.athlete_id, '50 antrenman tamamlandı', 'gelisim',
            current_date, 'attendance_50')
    on conflict do nothing;
  end if;

  if v_total >= 20 then
    v_rate := 100.0 * v_present / v_total;
    if v_rate >= 90 then
      insert into public.athlete_achievements
        (athlete_id, title, category, event_date, note, source)
      values (new.athlete_id, 'Düzenli katılım', 'gelisim', current_date,
              '%' || round(v_rate) || ' katılım (' || v_total || ' antrenman)',
              'attendance_rate_90')
      on conflict do nothing;
    end if;
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_award_attendance on public.attendance;
create trigger trg_award_attendance
  after insert or update on public.attendance
  for each row execute function public.award_attendance_achievements();

-- ---------------------------------------------------------------------------
-- 4) Sporcu kartı verisi — Swan Card'ın içi
--
-- Kart bugün yalnızca görsel: ad, branş, kulüp. Denetimde "dijital sporcu
-- CV'si" olması gerektiği çıktı. Gereken sayılar zaten tabloda; eksik olan
-- onları tek sorguda toplayan bir yerdi.
--
-- Tek RPC olmasının sebebi: kart dört ayrı tablodan besleniyor ve dördünü
-- ayrı ayrı çekmek kartı açan her ekranda dört gidiş-dönüş demekti.
-- ---------------------------------------------------------------------------
create or replace function public.athlete_card(p_athlete uuid)
returns table (
  trainings      int,     -- katıldığı antrenman
  attendance_pct int,     -- katılım oranı
  goals_done     int,     -- tamamlanan hedef
  goals_active   int,
  achievements   int,
  last_test      date,
  club_name      text,
  team_name      text
)
language sql
stable
security definer
set search_path = public
as $fn$
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
    -- En son katılınan takım. `created_at`'e göre — `id` uuid ve sıralaması
    -- rastgele; ona göre sıralamak kartta her seferinde farklı takım
    -- gösterebilirdi.
    (select t.name from public.team_memberships tm
       join public.teams t on t.id = tm.team_id
      where tm.athlete_id = p_athlete
      order by tm.created_at desc limit 1);
$fn$;

revoke execute on function public.athlete_card(uuid) from public, anon;
grant execute on function public.athlete_card(uuid) to authenticated;
