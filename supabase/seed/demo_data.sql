-- =============================================================================
-- SwanSport — DEMO VERİSİ
--
-- Uygulamayı dolu görebilmek için gerçekçi bir kulüp kurar: kadro, takımlar,
-- antrenman/maç takvimi, yoklama, aidat, tahsilat, sağlık kayıtları, tesisler,
-- belgeler, duyurular, performans testleri, gelişim hedefleri, bağış kampanyası
-- ve gönderiler.
--
-- KULLANIM — Supabase SQL editöründe, kendi e-postanla:
--     select public.seed_demo_data('senin@mailin.com');
--
-- Silmek için:
--     select public.clear_demo_data('senin@mailin.com');
--
-- NOT: SQL editörü `postgres` rolüyle çalışır, giriş yapmış kullanıcı gibi
-- değil — bu yüzden `auth.uid()` orada boştur ve hesabı e-postayla vermek
-- gerekir. Uygulama içinden çağrılırsa parametre gerekmez.
--
-- Tüm demo verisi "Demo Spor Kulübü" adlı ayrı bir kulübün altında durur;
-- kendi gerçek kulübüne dokunmaz. Tekrar çalıştırılabilir — ikinci kez
-- çalıştırınca veriyi çoğaltmaz.
--
-- ÖN KOŞUL: diğer kurulum dosyaları çalıştırılmış olmalı (özellikle
-- ATHLETE_PROFILE, COMMUNITIES, FEDERATION, PERFORMANCE ve FINANCE) — demo
-- verisi onların eklediği alanları kullanıyor.
-- =============================================================================



-- ---------------------------------------------------------------------------
-- Hedef hesabı çözer.
--
-- Uygulama içinden çağrıldığında `auth.uid()` doludur ve parametreye gerek
-- yoktur. Supabase SQL editöründe ise oturum yoktur; orada e-posta verilir.
-- ---------------------------------------------------------------------------
create or replace function public.demo_target_user(p_email text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid;
begin
  if p_email is not null and trim(p_email) <> '' then
    select id into v_uid from auth.users
     where lower(email) = lower(trim(p_email)) limit 1;
    if v_uid is null then
      raise exception 'Bu e-postayla kayıtlı kullanıcı yok: %', p_email;
    end if;
    return v_uid;
  end if;

  v_uid := auth.uid();
  if v_uid is null then
    raise exception
      'Hesap belirlenemedi. SQL editöründe e-postanı ver: '
      'select public.seed_demo_data(''senin@mailin.com'');';
  end if;
  return v_uid;
end;
$$;


drop function if exists public.seed_demo_data();
create or replace function public.seed_demo_data(p_email text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid    uuid := public.demo_target_user(p_email);
  v_club   uuid;
  v_season uuid;
  v_teamA  uuid;
  v_teamB  uuid;
  v_plan1  uuid;
  v_plan2  uuid;
  v_camp   uuid;
  v_ev     uuid;
  v_ath    uuid;
  v_inv    uuid;
  r        record;
  i        int;
  v_month  text;
  v_created int := 0;
begin
  -- ==========================================================  1) KULÜP
  select id into v_club
    from public.clubs
   where name = 'Demo Spor Kulübü' and created_by = v_uid
   limit 1;

  if v_club is null then
    insert into public.clubs (name, short_name, city, status, created_by,
                              bio, iban, bank_name, account_holder)
    values ('Demo Spor Kulübü', 'DSK', 'Konya', 'active', v_uid,
            'Demo amaçlı örnek kulüp. Altyapıdan A takıma voleybol.',
            'TR00 0000 0000 0000 0000 0000 00', 'Demo Bank',
            'Demo Spor Kulübü Derneği')
    returning id into v_club;
    v_created := v_created + 1;
  end if;

  -- Çağıran kişi kulübün yöneticisi olsun.
  -- NOT: tablodaki benzersizlik (club_id, profile_id, role, team_id) üzerinden
  -- kurulu; team_id boş olduğu için ON CONFLICT ikinci çalıştırmada yakalamaz,
  -- o yüzden varlık kontrolü elle yapılıyor.
  if not exists (select 1 from public.club_memberships
                  where club_id = v_club and profile_id = v_uid
                    and role = 'club_admin') then
    insert into public.club_memberships
      (club_id, profile_id, role, status, coach_level)
    values (v_club, v_uid, 'club_admin', 'active', 3);
  end if;

  -- Şehir + branş + onaylı antrenörlük: topluluk ve federasyon kanalları da
  -- demo hesapta çalışsın diye.
  update public.profiles set city_code = '42' where id = v_uid and city_code is null;

  if not exists (select 1 from public.profile_credentials
                  where profile_id = v_uid and kind = 'coach') then
    insert into public.profile_credentials
      (profile_id, kind, coach_level, sport_code, status, reviewed_at)
    values (v_uid, 'coach', 3, 'voleybol', 'approved', now());
  end if;

  -- ==========================================================  2) SEZON + TAKIM
  select id into v_season from public.seasons
   where club_id = v_club and label = '2025-2026 Sezonu' limit 1;
  if v_season is null then
    insert into public.seasons (club_id, label, starts_on, ends_on, is_active)
    values (v_club, '2025-2026 Sezonu', date '2025-09-01', date '2026-06-30', true)
    returning id into v_season;
  end if;

  select id into v_teamA from public.teams
   where club_id = v_club and name = 'U-16 Erkek' limit 1;
  if v_teamA is null then
    insert into public.teams (club_id, name, age_group, gender)
    values (v_club, 'U-16 Erkek', 'U-16', 'male') returning id into v_teamA;
  end if;

  select id into v_teamB from public.teams
   where club_id = v_club and name = 'U-14 Kız' limit 1;
  if v_teamB is null then
    insert into public.teams (club_id, name, age_group, gender)
    values (v_club, 'U-14 Kız', 'U-14', 'female') returning id into v_teamB;
  end if;

  -- ==========================================================  3) SPORCULAR
  if not exists (select 1 from public.athletes where club_id = v_club) then
    insert into public.athletes
      (club_id, first_name, last_name, birth_date, position, license_number,
       branch, jersey_number, height_cm, weight_kg, started_at)
    values
      (v_club,'Arda','Yılmaz',   date '2009-03-14','Pasör',   'LS-1001','voleybol', 7,178,68.5, date '2018-09-01'),
      (v_club,'Emir','Kaya',     date '2009-07-02','Smaçör',  'LS-1002','voleybol',10,183,72.0, date '2017-09-01'),
      (v_club,'Kerem','Demir',   date '2010-01-23','Libero',  'LS-1003','voleybol', 3,170,62.0, date '2019-02-01'),
      (v_club,'Yusuf','Şahin',   date '2009-11-05','Orta',    'LS-1004','voleybol', 5,188,76.5, date '2018-01-15'),
      (v_club,'Mert','Çelik',    date '2010-05-19','Smaçör',  'LS-1005','voleybol', 9,175,66.0, date '2019-09-01'),
      (v_club,'Ali','Aydın',     date '2009-09-30','Pasör',   'LS-1006','voleybol',12,176,67.0, date '2018-06-01'),
      (v_club,'Zeynep','Aksoy',  date '2011-02-11','Orta',    'LS-1007','voleybol', 4,172,58.0, date '2020-09-01'),
      (v_club,'Elif','Doğan',    date '2011-06-08','Libero',  'LS-1008','voleybol', 2,165,54.0, date '2020-09-01'),
      (v_club,'Defne','Arslan',  date '2011-10-27','Smaçör',  'LS-1009','voleybol', 8,174,59.5, date '2019-10-01'),
      (v_club,'Ayşe','Koç',      date '2012-01-16','Pasör',   'LS-1010','voleybol', 6,168,55.0, date '2021-01-10'),
      (v_club,'Ecrin','Polat',   date '2011-08-04','Orta',    'LS-1011','voleybol',11,177,60.0, date '2020-03-01'),
      (v_club,'Nehir','Yıldız',  date '2012-04-22','Smaçör',  'LS-1012','voleybol',14,169,56.0, date '2021-09-01');
    v_created := v_created + 12;
  end if;

  -- Takım kadroları: erkekler A, kızlar B.
  insert into public.team_memberships (athlete_id, team_id, season_id, jersey_number)
  select a.id,
         case when a.first_name in ('Arda','Emir','Kerem','Yusuf','Mert','Ali')
              then v_teamA else v_teamB end,
         v_season,
         a.jersey_number::text
    from public.athletes a
   where a.club_id = v_club
  on conflict do nothing;

  -- ==========================================================  4) TAKVİM
  if not exists (select 1 from public.events where club_id = v_club) then
    -- Geçmiş antrenmanlar (yoklama için)
    for i in 1..10 loop
      insert into public.events (club_id, team_id, title, place, kind, starts_at, ends_at)
      values (v_club, v_teamA, 'Antrenman', 'Merkez Salon', 'training',
              now() - ((i * 6) || ' days')::interval,
              now() - ((i * 6) || ' days')::interval + interval '90 minutes');
    end loop;

    -- Oynanmış maçlar (skorlu)
    insert into public.events
      (club_id, team_id, title, place, kind, starts_at, opponent, home_score, away_score, result_note)
    values
      (v_club, v_teamA, 'Lig Maçı', 'Merkez Salon', 'match',
       now() - interval '12 days', 'Selçuklu SK', 3, 1, 'İyi servis performansı'),
      (v_club, v_teamA, 'Lig Maçı', 'Deplasman', 'match',
       now() - interval '26 days', 'Meram Belediyespor', 2, 3, 'Son sette düşüş'),
      (v_club, v_teamB, 'Hazırlık Maçı', 'Merkez Salon', 'match',
       now() - interval '19 days', 'Karatay Gençlik', 3, 0, null);

    -- Gelecek etkinlikler
    insert into public.events (club_id, team_id, title, place, kind, starts_at, ends_at, opponent)
    values
      (v_club, v_teamA, 'Antrenman', 'Merkez Salon', 'training',
       now() + interval '2 days', now() + interval '2 days' + interval '90 minutes', null),
      (v_club, v_teamA, 'Lig Maçı', 'Merkez Salon', 'match',
       now() + interval '5 days', null, 'Ereğli Spor'),
      (v_club, v_teamB, 'Antrenman', 'Yan Salon', 'training',
       now() + interval '3 days', now() + interval '3 days' + interval '75 minutes', null),
      (v_club, null, 'Veli Toplantısı', 'Kulüp Lokali', 'meeting',
       now() + interval '9 days', null, null);
    v_created := v_created + 17;
  end if;

  -- ==========================================================  5) YOKLAMA
  -- Geçmiş antrenmanlara katılım. Devamsızlık dağınık olsun ki rapor anlamlı
  -- görünsün: her sporcunun oranı farklı çıkar.
  if not exists (select 1 from public.attendance where club_id = v_club) then
    for r in
      select e.id as event_id, a.id as athlete_id,
             row_number() over (order by e.starts_at, a.created_at) as n
        from public.events e
        cross join public.athletes a
       where e.club_id = v_club
         and a.club_id = v_club
         and e.kind = 'training'
         and e.starts_at < now()
    loop
      insert into public.attendance (club_id, event_id, athlete_id, status, taken_at)
      values (v_club, r.event_id, r.athlete_id,
              case
                when r.n % 11 = 0 then 'absent'::public.attendance_status
                when r.n % 17 = 0 then 'excused'::public.attendance_status
                when r.n % 23 = 0 then 'late'::public.attendance_status
                else 'present'::public.attendance_status
              end,
              now() - interval '1 day')
      on conflict do nothing;
    end loop;
  end if;

  -- ==========================================================  6) DUYURULAR
  if not exists (select 1 from public.announcements where club_id = v_club) then
    insert into public.announcements (club_id, author_id, title, body, pinned, created_at)
    values
      (v_club, v_uid, 'Sezon açılışı 8 Eylül',
       'Yeni sezon antrenmanları 8 Eylül Pazartesi başlıyor. Tüm sporcuların '
       'lisans yenileme belgelerini getirmesi gerekiyor.', true, now() - interval '20 days'),
      (v_club, v_uid, 'Aidat ödemeleri hakkında',
       'Aylık aidat son ödeme günü her ayın 10''udur. Havale sonrası uygulamadan '
       '"Ödedim" bildirimi yapmayı unutmayın.', false, now() - interval '12 days'),
      (v_club, v_uid, 'Deplasman servisi',
       'Cumartesi Ereğli deplasmanı için otobüs 08:30''da kulüp önünden kalkacak.',
       false, now() - interval '4 days'),
      (v_club, v_uid, 'Veli toplantısı',
       'Sezon değerlendirme toplantısı için tüm velileri bekliyoruz.',
       false, now() - interval '1 day');
    v_created := v_created + 4;
  end if;

  -- ==========================================================  7) TESİSLER
  if not exists (select 1 from public.facilities where club_id = v_club) then
    insert into public.facilities (club_id, name, kind, occupancy, status)
    values
      (v_club, 'Merkez Salon', 'Kapalı spor salonu', 85, 'Dolu'),
      (v_club, 'Yan Salon', 'Antrenman salonu', 40, 'Müsait'),
      (v_club, 'Kondisyon Odası', 'Fitness', 25, 'Müsait'),
      (v_club, 'Açık Saha', 'Dış mekân', 0, 'Bakımda');
    v_created := v_created + 4;
  end if;

  -- ==========================================================  8) BELGELER
  if not exists (select 1 from public.documents where club_id = v_club) then
    insert into public.documents (club_id, name, kind, size_label)
    values
      (v_club, 'Kulüp Tescil Belgesi', 'pdf', '1.2 MB'),
      (v_club, 'Sezon Lisans Listesi', 'xls', '340 KB'),
      (v_club, 'Salon Kullanım Protokolü', 'pdf', '780 KB'),
      (v_club, 'Veli Onay Formu', 'pdf', '210 KB'),
      (v_club, 'Antrenman Programı', 'file', '96 KB');
    v_created := v_created + 5;
  end if;

  -- ==========================================================  9) SAĞLIK
  if not exists (select 1 from public.injuries where club_id = v_club) then
    insert into public.injuries (club_id, athlete_id, status, note, created_at)
    select v_club, a.id,
           case a.first_name
             when 'Kerem' then 'injured'::public.fitness_status
             when 'Defne' then 'injured'::public.fitness_status
             when 'Mert'  then 'pending'::public.fitness_status
             else 'fit'::public.fitness_status
           end,
           case a.first_name
             when 'Kerem' then 'Ayak bileği burkulması — 2 hafta istirahat'
             when 'Defne' then 'Omuz zorlanması — fizyoterapi sürüyor'
             when 'Mert'  then 'Diz ağrısı şikâyeti, kontrol bekleniyor'
             else null
           end,
           now() - interval '8 days'
      from public.athletes a
     where a.club_id = v_club
       and a.first_name in ('Kerem', 'Defne', 'Mert');
    v_created := v_created + 3;
  end if;

  -- ==========================================================  10) AİDAT
  select id into v_plan1 from public.fee_plans
   where club_id = v_club and name = 'Altyapı — aylık' limit 1;
  if v_plan1 is null then
    insert into public.fee_plans (club_id, name, amount, due_day)
    values (v_club, 'Altyapı — aylık', 1500, 10) returning id into v_plan1;
  end if;

  select id into v_plan2 from public.fee_plans
   where club_id = v_club and name = 'A Takım — aylık' limit 1;
  if v_plan2 is null then
    insert into public.fee_plans (club_id, name, amount, due_day)
    values (v_club, 'A Takım — aylık', 2200, 5) returning id into v_plan2;
  end if;

  -- Sporculara plan ata. Kerem burslu (0), Ayşe kardeş indirimli (750).
  insert into public.athlete_fees (athlete_id, club_id, plan_id, custom_amount, note)
  select a.id, v_club,
         case when a.birth_date < date '2010-06-01' then v_plan2 else v_plan1 end,
         case a.first_name when 'Kerem' then 0 when 'Ayşe' then 750 else null end,
         case a.first_name when 'Kerem' then 'burslu sporcu'
                           when 'Ayşe' then 'kardeş indirimi' else null end
    from public.athletes a
   where a.club_id = v_club
  on conflict (athlete_id) do nothing;

  -- Son üç ayın tahakkuku.
  --
  -- generate_fee_charges() çağrılmıyor: o fonksiyon yetkiyi auth.uid() ile
  -- kontrol ediyor ve SQL editöründe oturum olmadığı için "Yetkisiz" derdi.
  -- Aynı mantık burada doğrudan yürütülüyor; benzersiz indeks yine çift
  -- tahakkuku engelliyor.
  for i in 0..2 loop
    v_month := to_char(now() - (i || ' months')::interval, 'YYYY-MM');

    insert into public.invoices
      (club_id, athlete_id, plan_id, label, amount, status, period, due_date, kind)
    select
      af.club_id, af.athlete_id, af.plan_id,
      fp.name || ' · ' || v_month,
      coalesce(af.custom_amount, fp.amount),
      'pending'::public.invoice_status,
      v_month,
      (to_date(v_month || '-01', 'YYYY-MM-DD')
        + (least(greatest(fp.due_day, 1), 28) - 1) * interval '1 day')::date,
      'aidat'
    from public.athlete_fees af
    join public.fee_plans fp on fp.id = af.plan_id
    where af.club_id = v_club
      and af.active
      and fp.active
      and coalesce(af.custom_amount, fp.amount) > 0
    on conflict do nothing;
  end loop;

  -- Eski ayları büyük ölçüde ödenmiş göster, bu ayı açık bırak.
  update public.invoices
     set status = 'paid'
   where club_id = v_club
     and period < to_char(now(), 'YYYY-MM')
     and status <> 'paid'
     and (extract(epoch from created_at)::bigint % 5) <> 0;

  -- Kulübün tahsil ettiği ödemeler (onaylı).
  if not exists (select 1 from public.payments where club_id = v_club) then
    insert into public.payments
      (club_id, invoice_id, athlete_id, amount, method, status,
       declared_by, confirmed_by, confirmed_at, paid_at)
    select v_club, iv.id, iv.athlete_id, iv.amount, 'havale', 'confirmed',
           v_uid, v_uid, now(), current_date - 12
      from public.invoices iv
     where iv.club_id = v_club and iv.status = 'paid'
     limit 15;

    -- Onay bekleyen iki bildirim: "Ödemeler" sekmesi boş görünmesin.
    insert into public.payments
      (club_id, invoice_id, athlete_id, amount, method, status, note,
       declared_by, paid_at)
    select v_club, iv.id, iv.athlete_id, iv.amount, 'havale', 'pending',
           'Havale yaptım, dekont ektedir.', v_uid, current_date - 1
      from public.invoices iv
     where iv.club_id = v_club and iv.status <> 'paid'
     limit 2;
  end if;

  -- ==========================================================  11) PERFORMANS
  if not exists (select 1 from public.performance_tests
                  where athlete_id in (select id from public.athletes where club_id = v_club)) then
    -- Her sporcuya üç ölçüm: sprint (küçük iyi) ve dikey sıçrama (büyük iyi).
    for r in select id, row_number() over (order by created_at) as n
               from public.athletes where club_id = v_club loop
      for i in 0..2 loop
        insert into public.performance_tests
          (athlete_id, category, test_name, value, unit, lower_is_better,
           test_date, assessor_id)
        values
          (r.id, 'surat', '30 m Sprint',
           4.9 - (i * 0.07) + (r.n % 4) * 0.05, 'sn', true,
           (current_date - ((2 - i) * 30)), v_uid),
          (r.id, 'kuvvet', 'Dikey Sıçrama',
           42 + (i * 2) + (r.n % 5), 'cm', false,
           (current_date - ((2 - i) * 30)), v_uid);
      end loop;
    end loop;

    insert into public.development_goals
      (athlete_id, title, category, progress, target_date, created_by, note)
    select a.id,
           case when a.jersey_number % 3 = 0 then 'Sprint süresini 4.6 sn altına indir'
                when a.jersey_number % 3 = 1 then 'Dikey sıçramayı 50 cm''e çıkar'
                else 'Servis isabetini %70''e çıkar' end,
           case when a.jersey_number % 3 = 0 then 'surat'
                when a.jersey_number % 3 = 1 then 'kuvvet' else 'teknik' end,
           (a.jersey_number * 7) % 100,
           current_date + 60, v_uid, 'Sezon içi gelişim hedefi'
      from public.athletes a
     where a.club_id = v_club;
  end if;

  -- ==========================================================  12) BAĞIŞ
  select id into v_camp from public.donation_campaigns
   where club_id = v_club and title = 'Deplasman otobüsü' limit 1;
  if v_camp is null then
    insert into public.donation_campaigns
      (club_id, title, description, target, status, ends_at, created_by)
    values (v_club, 'Deplasman otobüsü',
            'Sezon boyunca deplasman maçlarına gidebilmemiz için otobüs '
            'kiralama masrafını karşılamak istiyoruz.',
            50000, 'active', current_date + 45, v_uid)
    returning id into v_camp;

    insert into public.donations
      (campaign_id, club_id, donor_id, donor_name, amount, message, anonymous, status)
    values
      (v_camp, v_club, v_uid, 'Demo Destekçi', 5000, 'Başarılar!', false, 'confirmed'),
      (v_camp, v_club, null, 'Ahmet Veli', 2500, 'Çocuklar için', false, 'confirmed'),
      (v_camp, v_club, null, 'İsimsiz', 1000, null, true, 'confirmed'),
      (v_camp, v_club, null, 'Mahalle Esnafı', 7500, 'Kolay gelsin', false, 'confirmed'),
      (v_camp, v_club, null, 'Yeni Bağışçı', 1500, 'Onay bekliyor', false, 'pending');
    v_created := v_created + 6;
  end if;

  -- ==========================================================  13) GÖNDERİLER
  if not exists (select 1 from public.posts where club_id = v_club) then
    insert into public.posts (author_profile_id, club_id, body, created_at)
    values
      (v_uid, v_club, 'Sezonun ilk lig maçını 3-1 kazandık. Tüm takımı tebrik '
       'ediyoruz! 🏐', now() - interval '11 days'),
      (v_uid, v_club, 'U-14 kız takımımız hazırlık maçında set vermeden kazandı.',
       now() - interval '18 days'),
      (v_uid, v_club, 'Yeni sezon formalarımız geldi. Sporcularımıza hayırlı olsun.',
       now() - interval '6 days');
    insert into public.posts (author_profile_id, body, created_at)
    values (v_uid, 'Antrenörlük kademe belgemi yeniledim, yeni sezona hazırız.',
            now() - interval '3 days');
    v_created := v_created + 4;
  end if;

  return format(
    'Demo kulüp hazır: %s sporcu, %s etkinlik, %s fatura, %s ödeme. '
    'Uygulamada "Demo Spor Kulübü" görünecek.',
    (select count(*) from public.athletes where club_id = v_club),
    (select count(*) from public.events where club_id = v_club),
    (select count(*) from public.invoices where club_id = v_club),
    (select count(*) from public.payments where club_id = v_club));
end;
$$;


-- ---------------------------------------------------------------------------
-- Temizlik: demo kulübü siler. Kulüp silinince ona bağlı her şey (sporcu,
-- etkinlik, fatura, ödeme, tesis, belge, kampanya, gönderi) birlikte gider.
-- ---------------------------------------------------------------------------
drop function if exists public.clear_demo_data();
create or replace function public.clear_demo_data(p_email text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := public.demo_target_user(p_email); v_n int;
begin
  delete from public.clubs
   where name = 'Demo Spor Kulübü' and created_by = v_uid;
  get diagnostics v_n = row_count;

  return case when v_n > 0
              then 'Demo verisi silindi.'
              else 'Silinecek demo verisi bulunamadı.' end;
end;
$$;


-- ---------------------------------------------------------------------------
-- İsteğe bağlı: yönetim panelini de dolu görmek için hesabı platform
-- yöneticisi yapar. Bunu yalnızca kendi test hesabında çalıştır.
--     select public.seed_make_me_platform_admin('senin@mailin.com');
-- ---------------------------------------------------------------------------
drop function if exists public.seed_make_me_platform_admin();
create or replace function public.seed_make_me_platform_admin(
  p_email text default null)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v_uid uuid := public.demo_target_user(p_email);
begin
  update public.profiles set is_platform_admin = true where id = v_uid;
  return 'Artık platform yöneticisisin — Onay Paneli açılacak.';
end;
$$;
