-- 0044 — Gelişim döngüsünü kapat
--
-- Denetimde çıkan bulgu: `performance_tests`, `development_goals` ve
-- `athlete_achievements` tablolarının üçü de YALNIZCA `athletes`'a referans
-- veriyor. Birbirlerini ve etkinlikleri tanımıyorlar. Bu yüzden şu üç cümle
-- veriyle ifade edilemiyordu:
--
--   "Bu ölçüm şu antrenmanda alındı"
--   "Bu hedef şu ölçümle takip ediliyor"
--   "Bu başarı şu hedeften doğdu"
--
-- Bu migration ilk ikisini bağlıyor. Yeni tablo açmıyor — mevcut tablolara
-- sütun ekliyor, çünkü veri modeli zaten doğru yerde duruyordu, yalnızca
-- birbirine bakmıyordu.

-- ---------------------------------------------------------------------------
-- 1) Ölçüm hangi antrenmanda alındı
-- ---------------------------------------------------------------------------
alter table public.performance_tests
  add column if not exists event_id uuid references public.events(id) on delete set null;

create index if not exists idx_perf_event
  on public.performance_tests (event_id);

comment on column public.performance_tests.event_id is
  'Ölçümün alındığı antrenman/etkinlik. Boş olabilir: kulüp dışında alınan '
  'ölçümler ve 0044 öncesi kayıtlar bağsız kalır.';

-- ---------------------------------------------------------------------------
-- 2) Hedef ölçülebilir hale gelsin
--
-- Eskiden `progress` (0-100) elle giriliyordu. Elle girilen ilerleme kimsenin
-- girmediği ilerlemedir: sporcu kendi hedefini güncellemeyi unutuyor, antrenör
-- de her hedefi tek tek gezmiyor. Ölçüm zaten sisteme giriliyor; hedefi ona
-- bağlayınca ilerleme kendiliğinden hesaplanıyor.
-- ---------------------------------------------------------------------------
alter table public.development_goals
  add column if not exists test_name      text,
  add column if not exists baseline_value numeric(10,2),
  add column if not exists target_value   numeric(10,2),
  add column if not exists last_value     numeric(10,2),
  add column if not exists measured_at    timestamptz;

comment on column public.development_goals.test_name is
  'Bu hedefi ölçen testin adı (performance_tests.test_name ile eşleşir). '
  'Boşsa hedef elle takip edilir — eski davranış korunuyor.';

-- Ölçülebilir hedefte üç alan birlikte anlamlı: ölçüm adı, başlangıç, hedef.
-- Yarısı dolu bir hedef ilerleme hesaplayamaz ve sessizce yanlış görünür.
do $$ begin
  alter table public.development_goals
    add constraint development_goals_metric_complete
    check (
      test_name is null
      or (baseline_value is not null and target_value is not null)
    );
exception when duplicate_object then null; end $$;

-- Başlangıç ile hedef aynıysa bölme sıfıra düşer.
do $$ begin
  alter table public.development_goals
    add constraint development_goals_metric_range
    check (test_name is null or baseline_value <> target_value);
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- 3) İlerleme hesabı
--
-- Yönü testin kendisi söylüyor: `performance_tests.lower_is_better`.
-- Sprintte küçük değer iyidir, sıçramada büyük. Bunu hedefte tekrar tutmak
-- iki yerde ayrışacak bir gerçek olurdu.
-- ---------------------------------------------------------------------------
create or replace function public.goal_progress(
  p_baseline numeric,
  p_target   numeric,
  p_current  numeric,
  p_lower_is_better boolean
)
returns int
language sql
immutable
as $fn$
  select greatest(0, least(100, round(
    case when p_lower_is_better
         then (p_baseline - p_current) / nullif(p_baseline - p_target, 0)
         else (p_current - p_baseline) / nullif(p_target - p_baseline, 0)
    end * 100
  )))::int;
$fn$;

-- ---------------------------------------------------------------------------
-- 4) Yeni ölçüm girilince ilgili hedefler kendiliğinden ilerlesin
-- ---------------------------------------------------------------------------
create or replace function public.apply_test_to_goals()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  update public.development_goals g
     set last_value  = new.value,
         measured_at = now(),
         progress    = public.goal_progress(
                         g.baseline_value, g.target_value,
                         new.value, new.lower_is_better),
         -- Hedefe ulaşıldıysa durumu da kapat. `at_risk` olanlar da buradan
         -- `done`'a geçebilir: ölçüm hedefi tutturmuşsa risk kalmamıştır.
         status = case
                    when public.goal_progress(
                           g.baseline_value, g.target_value,
                           new.value, new.lower_is_better) >= 100
                    then 'done' else g.status end
   where g.athlete_id = new.athlete_id
     and g.test_name  = new.test_name
     -- Kapanmış hedefi geri açma: sporcu hedefi tutturduktan sonra düşen bir
     -- ölçüm, kazanılmış başarıyı geri almamalı.
     and g.status <> 'done'
     and g.baseline_value is not null
     and g.target_value is not null;

  return new;
end;
$fn$;

drop trigger if exists trg_apply_test_to_goals on public.performance_tests;
create trigger trg_apply_test_to_goals
  after insert on public.performance_tests
  for each row execute function public.apply_test_to_goals();

-- ---------------------------------------------------------------------------
-- 5) Yoklama artık etkinliğe bağlanacak
--
-- `attendance.event_id` sütunu 0007'den beri VAR ama uygulama hiç yazmıyordu;
-- her satır NULL geliyordu. Sonucu iki katmanlı:
--
--   * Yoklama hiçbir antrenmana ait değil — RSVP ile eşleştirilemiyor,
--     etkinlik bazlı geçmiş çıkarılamıyor.
--   * `unique (event_id, athlete_id)` kısıtı işlevsiz kalıyor: Postgres'te
--     NULL'lar birbiriyle çakışmadığı için aynı sporcu için sınırsız tekrar
--     satır yazılabiliyor.
--
-- Sütunu `not null` yapamıyoruz — eski satırlar NULL ve onları uydurma bir
-- etkinliğe bağlamak veriyi bozardı.
--
-- "Etkinliksiz yoklamada günde tek satır" garantisi için kısmi bir indeks
-- denendi ve **vazgeçildi**: indeks ifadesi IMMUTABLE olmak zorunda,
-- `taken_at at time zone 'Europe/Istanbul'` ise STABLE (sunucunun zaman dilimi
-- ayarına bağlı). Postgres böyle bir indeksi reddediyor. Zorlamanın yolu
-- `taken_at`'i sabit bir offset'le hesaplamaktı; yaz saati değişimini
-- kaybettirdiği için yanlış olurdu.
--
-- Korumayı asıl sağlayan şey şu: uygulama artık her yoklamada `event_id`
-- yazıyor (bu sürümden itibaren), o zaman da mevcut
-- `unique (event_id, athlete_id)` kısıtı devreye giriyor. Etkinliksiz yoklama
-- yalnızca eski kayıtlarda kalıyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 6) Bir etkinliğin RSVP'leri — yoklama ekranını ön-doldurmak için
--
-- Antrenör 18 kişilik kadroyu tek tek işaretliyordu; oysa kimin geleceği
-- RSVP'de zaten yazılı. İki tablo aynı `(event_id, athlete_id)` anahtarını
-- paylaşıyor, sadece kimse birleştirmemiş.
--
-- RPC olmasının sebebi: ekran hem RSVP'yi hem o etkinliğin mevcut yoklamasını
-- bir arada istiyor. İki ayrı sorgu ile çekmek, ekranın iki kaynağı elde
-- birleştirmesi demekti.
-- ---------------------------------------------------------------------------
create or replace function public.event_roster(p_event uuid)
returns table (
  athlete_id   uuid,
  full_name    text,
  rsvp         text,   -- attending | uncertain | unavailable | null
  attendance   text    -- daha önce kaydedilmiş yoklama, varsa
)
language sql
stable
security definer
set search_path = public
as $fn$
  with ev as (select * from public.events where id = p_event)
  select a.id,
         -- `athletes` tablosunda `full_name` yok; ad ve soyad ayrı sütunlarda.
         trim(a.first_name || ' ' || a.last_name),
         r.status::text,
         at.status::text
    from ev
    join public.athletes a on a.club_id = ev.club_id
    left join public.event_rsvps r
           on r.event_id = ev.id and r.athlete_id = a.id
    left join public.attendance at
           on at.event_id = ev.id and at.athlete_id = a.id
   where
     -- Etkinlik bir takıma bağlıysa yalnızca o takımın sporcuları.
     ev.team_id is null
     or exists (select 1 from public.team_memberships tm
                 where tm.team_id = ev.team_id and tm.athlete_id = a.id)
   order by a.first_name, a.last_name;
$fn$;

revoke execute on function public.event_roster(uuid) from public, anon;
grant execute on function public.event_roster(uuid) to authenticated;

revoke execute on function public.goal_progress(numeric, numeric, numeric, boolean)
  from public, anon;
grant execute on function public.goal_progress(numeric, numeric, numeric, boolean)
  to authenticated;
