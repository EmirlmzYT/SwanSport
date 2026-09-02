-- ---------------------------------------------------------------------------
-- 0072 — Antrenman oturum motoru: RPC'ler
--
-- GÜVENLİK NOTU: buradaki fonksiyonların hepsi `security definer`, yani
-- RLS'i AŞIYORLAR. RLS doğrudan tablo erişimini koruyor; RPC içi yetki
-- kontrolünün yerine geçmiyor. Her gövde kendi yetkisini ayrıca ölçüyor.
--
-- "Kodu bilmiyor" bir erişim kontrolü değil: `join_training_session` katılım
-- kodunu doğruladıktan SONRA kulüp ve takım kapsamını ayrıca kesiyor.
--
-- Muhasebeci bu dosyada hiç geçmiyor. `is_club_staff` muhasebeciyi saymıyor
-- (0049) ve hiçbir gövdede `club_accountants` sorgulanmıyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) Aşama makinesi
--
-- SUNUCU TEK OTORİTE. Dart tarafındaki `nextPhase` yalnızca "sıradaki:
-- Ok Toplama" önizlemesi için; gerçek geçişi burası yapıyor. İki tarafta
-- iki ayrı otorite olsaydı biri diğerinden kayardı.
--
-- Süresi 0 olan `collect` ve `rest` atlanıyor: sıfır saniyelik bir aşamayı
-- göstermek, ekranda bir kare titreyip geçen bir adım demek.
-- `prep` atlanmıyor — o bir sayaç değil, "başla" kapısı.
-- ---------------------------------------------------------------------------
create or replace function public.training_next_phase(
  p_phase text, p_set int, p_config jsonb)
returns jsonb
language sql
immutable
as $fn$
  with c as (
    select coalesce((p_config->>'set_count')::int, 1)       as set_count,
           coalesce((p_config->>'collect_seconds')::int, 0) as collect_s,
           coalesce((p_config->>'rest_seconds')::int, 0)    as rest_s
  )
  select case p_phase
    when 'prep' then jsonb_build_object('phase', 'shoot', 'set_no', p_set)
    when 'shoot' then
      case when c.collect_s > 0
        then jsonb_build_object('phase', 'collect', 'set_no', p_set)
        else jsonb_build_object('phase', 'score', 'set_no', p_set)
      end
    when 'collect' then jsonb_build_object('phase', 'score', 'set_no', p_set)
    when 'score' then
      case
        when p_set >= c.set_count
          then jsonb_build_object('phase', 'done', 'set_no', p_set)
        when c.rest_s > 0
          then jsonb_build_object('phase', 'rest', 'set_no', p_set)
        else jsonb_build_object('phase', 'prep', 'set_no', p_set + 1)
      end
    when 'rest' then jsonb_build_object('phase', 'prep', 'set_no', p_set + 1)
    else jsonb_build_object('phase', 'done', 'set_no', p_set)
  end
  from c;
$fn$;

-- Aşamanın süresi. `score` bilerek NULL: skor girişi sayaçla sınırlanmıyor,
-- yarım kalan giriş kaydedilemezdi.
create or replace function public.training_phase_seconds(
  p_phase text, p_config jsonb)
returns int
language sql
immutable
as $fn$
  select case p_phase
    when 'prep'    then coalesce((p_config->>'prep_seconds')::int, 0)
    when 'shoot'   then coalesce((p_config->>'shoot_seconds')::int, 0)
    when 'collect' then coalesce((p_config->>'collect_seconds')::int, 0)
    when 'rest'    then coalesce((p_config->>'rest_seconds')::int, 0)
    else null
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- 2) Şablon değişmezliği
--
-- Sürümleme "yeni satır yaz" diye yazılmış olsa da, doğrudan `update`
-- yapılabilseydi geçmiş oturumların anlamı sessizce değişirdi. Kural
-- veritabanında.
-- ---------------------------------------------------------------------------
create or replace function public.guard_training_protocol_immutable()
returns trigger
language plpgsql
as $fn$
begin
  if new.config is distinct from old.config
     and exists (select 1 from public.training_sessions s
                  where s.protocol_id = old.id) then
    raise exception
      'Kullanılmış şablonun yapılandırması değiştirilemez; yeni sürüm oluşturun'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_training_protocol_immutable on public.training_protocols;
create trigger trg_training_protocol_immutable
  before update on public.training_protocols
  for each row execute function public.guard_training_protocol_immutable();

-- ---------------------------------------------------------------------------
-- 3) Şablon yönetimi
-- ---------------------------------------------------------------------------
create or replace function public.create_training_protocol(
  p_club uuid,
  p_sport text,
  p_name text,
  p_description text default null,
  p_config jsonb default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare v_id uuid;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Şablon oluşturmak için kulüp yetkilisi olmalısın';
  end if;
  if not public.valid_training_config(p_config) then
    raise exception 'Şablon yapılandırması geçersiz';
  end if;

  insert into public.training_protocols
    (club_id, sport_code, name, description, config, published, created_by)
  values (p_club, p_sport, trim(p_name), nullif(trim(coalesce(p_description, '')), ''),
          p_config, true, auth.uid())
  returning id into v_id;

  return v_id;
end;
$fn$;

-- Düzenleme = yeni sürüm. Eski satır olduğu gibi duruyor, ona bağlı
-- oturumlar bozulmuyor.
create or replace function public.revise_training_protocol(
  p_protocol uuid,
  p_name text default null,
  p_description text default null,
  p_config jsonb default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare v_old public.training_protocols%rowtype;
        v_id  uuid;
        v_cfg jsonb;
begin
  select * into v_old from public.training_protocols where id = p_protocol;
  if not found then
    raise exception 'Şablon bulunamadı';
  end if;
  if v_old.club_id is null then
    raise exception 'Platform şablonu düzenlenemez; kulübüne kopyala';
  end if;
  if not public.is_club_staff(v_old.club_id) then
    raise exception 'Şablon düzenlemek için kulüp yetkilisi olmalısın';
  end if;

  v_cfg := coalesce(p_config, v_old.config);
  if not public.valid_training_config(v_cfg) then
    raise exception 'Şablon yapılandırması geçersiz';
  end if;

  insert into public.training_protocols
    (club_id, sport_code, name, description, version, parent_id,
     config, published, created_by)
  values (v_old.club_id, v_old.sport_code,
          coalesce(nullif(trim(coalesce(p_name, '')), ''), v_old.name),
          coalesce(p_description, v_old.description),
          v_old.version + 1, v_old.id, v_cfg, v_old.published, auth.uid())
  returning id into v_id;

  update public.training_protocols set archived_at = now() where id = v_old.id;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 4) Oturum başlatma
--
-- Katılım kodunda karıştırılabilir karakterler yok (0/O, 1/I/L): sahada
-- sesli okunan bir kod bu yüzden yanlış yazılıyor.
-- ---------------------------------------------------------------------------
create or replace function public.generate_join_code()
returns text
language sql
volatile
as $fn$
  select string_agg(
    substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789',
           1 + floor(random() * 31)::int, 1), '')
  from generate_series(1, 6);
$fn$;

create or replace function public.start_training_session(
  p_club uuid,
  p_protocol uuid,
  p_event uuid default null,
  p_team uuid default null,
  p_rhythm text default 'shared')
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_cfg   jsonb;
        v_pclub uuid;
        v_id    uuid;
        v_code  text;
        v_secs  int;
        v_try   int := 0;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Oturum başlatmak için kulüp yetkilisi olmalısın';
  end if;
  if p_rhythm not in ('shared', 'individual', 'mixed') then
    raise exception 'Geçersiz katılım biçimi';
  end if;

  select config, club_id into v_cfg, v_pclub
    from public.training_protocols where id = p_protocol;
  if v_cfg is null then
    raise exception 'Şablon bulunamadı';
  end if;
  -- Başka kulübün şablonuyla oturum açılamaz. Platform şablonu (club_id
  -- null) herkese açık.
  if v_pclub is not null and v_pclub <> p_club then
    raise exception 'Bu şablon kulübüne ait değil';
  end if;

  if p_event is not null then
    if not exists (select 1 from public.events e
                    where e.id = p_event and e.club_id = p_club
                      and e.kind in ('training', 'match')) then
      raise exception 'Etkinlik bu kulübe ait bir antrenman veya müsabaka değil';
    end if;
  end if;
  if p_team is not null then
    if not exists (select 1 from public.teams t
                    where t.id = p_team and t.club_id = p_club) then
      raise exception 'Takım bu kulübe ait değil';
    end if;
  end if;

  -- Kısmi tekil indeks yarışı çözüyor; birkaç deneme yeterli.
  loop
    v_try := v_try + 1;
    v_code := public.generate_join_code();
    exit when not exists (
      select 1 from public.training_sessions
       where join_code = v_code and status = 'live');
    if v_try > 10 then
      raise exception 'Katılım kodu üretilemedi, tekrar dene';
    end if;
  end loop;

  v_secs := public.training_phase_seconds('prep', v_cfg);

  insert into public.training_sessions
    (club_id, protocol_id, kind, event_id, team_id, rhythm, status,
     current_set, current_phase, phase_started_at, phase_ends_at,
     join_code, join_code_expires_at, created_by)
  values (p_club, p_protocol, 'club', p_event, p_team, p_rhythm, 'live',
          1, 'prep', now(),
          case when coalesce(v_secs, 0) > 0
               then now() + make_interval(secs => v_secs) end,
          v_code, now() + interval '6 hours', auth.uid())
  returning id into v_id;

  insert into public.training_session_events (session_id, actor_id, action, phase)
  values (v_id, auth.uid(), 'start', 'prep');

  return jsonb_build_object('id', v_id, 'join_code', v_code);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 5) Oturuma katılma
--
-- KATILIM YOKLAMA DEĞİL. Burada `attendance` tablosuna hiçbir şey
-- yazılmıyor. Resmî yoklama mevcut güvenli akıştan kaydediliyor; bu satır
-- antrenöre yalnızca ipucu gösteriyor.
-- ---------------------------------------------------------------------------
create or replace function public.join_training_session(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s       public.training_sessions%rowtype;
        v_athlete uuid;
        v_blocked boolean;
        v_label   text;
begin
  select * into v_s from public.training_sessions
   where join_code = upper(trim(p_code)) and status = 'live';
  if not found then
    raise exception 'Kod geçersiz ya da oturum kapanmış';
  end if;
  if v_s.join_code_expires_at is not null
     and v_s.join_code_expires_at < now() then
    raise exception 'Katılım kodunun süresi dolmuş';
  end if;

  -- KAPSAM: sporcunun bu kulüpteki kaydı yoksa kod doğru olsa bile giremez.
  select a.id into v_athlete from public.athletes a
   where a.profile_id = auth.uid()
     and a.club_id = v_s.club_id
     and a.status = 'active'
   limit 1;
  if v_athlete is null then
    raise exception 'Bu oturum senin kulübüne ait değil';
  end if;

  if v_s.team_id is not null
     and not exists (select 1 from public.team_memberships tm
                      where tm.athlete_id = v_athlete
                        and tm.team_id = v_s.team_id) then
    raise exception 'Bu oturum başka bir takımın';
  end if;

  -- Uygunluk kilidi: yalnızca "uygun değil" ve gerekçe ETİKETİ. Tanı,
  -- doktor notu ve belge içeriği bu modüle taşınmıyor.
  select g.blocked, g.reason_label into v_blocked, v_label
    from public.eligibility_gate(v_athlete) g;
  if coalesce(v_blocked, false) then
    raise exception 'Şu an antrenmana uygun değilsin: %', coalesce(v_label, 'kulüp kaydı');
  end if;

  insert into public.training_session_participants (session_id, athlete_id)
  values (v_s.id, v_athlete)
  on conflict (session_id, athlete_id) do update set left_at = null;

  return jsonb_build_object('session_id', v_s.id, 'athlete_id', v_athlete);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 6) Aşama ilerletme, duraklatma
--
-- Süre dolduğunda sunucu KENDİLİĞİNDEN İLERLEMİYOR. Sahte durum üretmek
-- yerine ekran "süre doldu" diyor ve kararı insana bırakıyor.
-- ---------------------------------------------------------------------------
create or replace function public.advance_session_phase(
  p_session uuid,
  p_phase text default null,
  p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s    public.training_sessions%rowtype;
        v_cfg  jsonb;
        v_next jsonb;
        v_ph   text;
        v_set  int;
        v_secs int;
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu yönetme yetkin yok';
  end if;

  select * into v_s from public.training_sessions where id = p_session;
  if v_s.status <> 'live' then
    raise exception 'Oturum canlı değil';
  end if;

  select config into v_cfg from public.training_protocols where id = v_s.protocol_id;

  if p_phase is null then
    v_next := public.training_next_phase(v_s.current_phase, v_s.current_set, v_cfg);
    v_ph   := v_next->>'phase';
    v_set  := (v_next->>'set_no')::int;
  else
    if p_phase not in ('prep', 'shoot', 'collect', 'score', 'rest', 'done') then
      raise exception 'Geçersiz aşama';
    end if;
    v_ph  := p_phase;
    v_set := v_s.current_set;
  end if;

  v_secs := public.training_phase_seconds(v_ph, v_cfg);

  update public.training_sessions
     set current_phase = v_ph,
         current_set   = v_set,
         phase_started_at = now(),
         phase_ends_at = case when coalesce(v_secs, 0) > 0
                              then now() + make_interval(secs => v_secs) end,
         paused_at = null,
         status    = case when v_ph = 'done' then 'review' else status end,
         ended_at  = case when v_ph = 'done' then now() else ended_at end
   where id = p_session;

  insert into public.training_session_events
    (session_id, actor_id, action, reason, phase, set_no, old_value, new_value)
  values (p_session, auth.uid(),
          case when p_phase is null then 'advance' else 'skip' end,
          nullif(trim(coalesce(p_reason, '')), ''), v_ph, v_set,
          jsonb_build_object('phase', v_s.current_phase, 'set_no', v_s.current_set),
          jsonb_build_object('phase', v_ph, 'set_no', v_set));

  return jsonb_build_object('phase', v_ph, 'set_no', v_set);
end;
$fn$;

create or replace function public.set_training_pause(
  p_session uuid,
  p_paused boolean,
  p_reason text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s public.training_sessions%rowtype;
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu yönetme yetkin yok';
  end if;
  select * into v_s from public.training_sessions where id = p_session;

  if p_paused then
    if v_s.paused_at is not null then return; end if;
    update public.training_sessions set paused_at = now() where id = p_session;
  else
    if v_s.paused_at is null then return; end if;
    -- Bitiş zamanı duraklama süresi kadar ileri kayıyor; kalan süre korunuyor.
    update public.training_sessions
       set phase_ends_at = case when phase_ends_at is not null
                                then phase_ends_at + (now() - paused_at) end,
           paused_at = null
     where id = p_session;
  end if;

  insert into public.training_session_events
    (session_id, actor_id, action, reason, phase, set_no)
  values (p_session, auth.uid(),
          case when p_paused then 'pause' else 'resume' end,
          nullif(trim(coalesce(p_reason, '')), ''),
          v_s.current_phase, v_s.current_set);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 7) Skor girişi
--
-- EKSİK ≠ SIFIR. Girilmeyen set `total_score is null` kalıyor, atılmayan ok
-- `score is null`. Sıfır yazmak "kötü atmış" demek olurdu.
-- ---------------------------------------------------------------------------
create or replace function public.submit_set_score(
  p_session uuid,
  p_set_no int,
  p_total numeric default null,
  p_entries jsonb default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_s       public.training_sessions%rowtype;
        v_cfg     jsonb;
        v_athlete uuid;
        v_mode    text;
        v_units   int;
        v_max     numeric;
        v_total   numeric;
        v_count   int;
        v_set_id  uuid;
begin
  select * into v_s from public.training_sessions where id = p_session;
  if not found then
    raise exception 'Oturum bulunamadı';
  end if;
  if v_s.status not in ('live', 'review') then
    raise exception 'Oturum kapanmış';
  end if;

  if v_s.kind = 'personal' then
    if not public.is_athlete_self(v_s.athlete_id) then
      raise exception 'Bu oturum senin değil';
    end if;
    v_athlete := v_s.athlete_id;
  else
    select a.id into v_athlete from public.athletes a
     where a.profile_id = auth.uid() and a.club_id = v_s.club_id
       and a.status = 'active'
     limit 1;
    if v_athlete is null then
      raise exception 'Bu oturuma kayıtlı değilsin';
    end if;
    if not exists (select 1 from public.training_session_participants p
                    where p.session_id = p_session and p.athlete_id = v_athlete) then
      raise exception 'Önce oturuma katılmalısın';
    end if;
  end if;

  select config into v_cfg from public.training_protocols where id = v_s.protocol_id;
  v_mode  := v_cfg->>'entry_mode';
  v_units := (v_cfg->>'units_per_set')::int;
  v_max   := (v_cfg->>'max_unit_score')::numeric;

  if p_set_no < 1 or p_set_no > (v_cfg->>'set_count')::int then
    raise exception 'Set numarası protokol dışında';
  end if;

  if v_mode = 'simple' and p_entries is not null then
    raise exception 'Bu oturumda yalnızca set toplamı giriliyor';
  end if;
  if v_mode = 'detailed' and p_entries is null then
    raise exception 'Bu oturumda her atışın puanı tek tek giriliyor';
  end if;

  if p_entries is not null then
    if jsonb_typeof(p_entries) <> 'array' then
      raise exception 'Atış listesi dizi olmalı';
    end if;
    if jsonb_array_length(p_entries) > v_units then
      raise exception 'Protokolde set başına en fazla % atış var', v_units;
    end if;
    if exists (
      select 1 from jsonb_array_elements(p_entries) e
       where jsonb_typeof(e.value) not in ('number', 'null')
          or (jsonb_typeof(e.value) = 'number'
              and ((e.value)::text::numeric < 0
                or (e.value)::text::numeric > v_max))
    ) then
      raise exception 'Atış puanı 0 ile % arasında olmalı', v_max;
    end if;

    select sum((e.value)::text::numeric), count(*)
      into v_total, v_count
      from jsonb_array_elements(p_entries) e
     where jsonb_typeof(e.value) = 'number';
  else
    v_total := p_total;
    v_count := null;
    if v_total is not null
       and (v_total < 0 or v_total > v_units * v_max) then
      raise exception 'Set toplamı 0 ile % arasında olmalı', v_units * v_max;
    end if;
  end if;

  insert into public.training_sets
    (session_id, athlete_id, set_no, total_score, unit_count, completed_at)
  values (p_session, v_athlete, p_set_no, v_total, v_count, now())
  on conflict (session_id, athlete_id, set_no) do update
    set total_score  = excluded.total_score,
        unit_count   = excluded.unit_count,
        completed_at = now()
  where training_sets.locked_at is null
  returning id into v_set_id;

  if v_set_id is null then
    raise exception 'Bu set antrenör tarafından onaylanmış, düzeltilemez';
  end if;

  delete from public.training_set_entries where set_id = v_set_id;
  if p_entries is not null then
    insert into public.training_set_entries (set_id, seq, score)
    select v_set_id, e.ord,
           case when jsonb_typeof(e.value) = 'number'
                then (e.value)::text::numeric end
      from jsonb_array_elements(p_entries) with ordinality as e(value, ord);
  end if;

  return jsonb_build_object('set_id', v_set_id, 'total', v_total,
                            'units', v_count);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 8) Kulvar atama — İSTEĞE BAĞLI
--
-- Ürün kararı: sporcu kulvar seçmiyor. Antrenör isterse atıyor, atamazsa
-- sistem yalnızca katılımcı listesiyle çalışıyor.
-- ---------------------------------------------------------------------------
create or replace function public.assign_session_lane(
  p_session uuid, p_athlete uuid, p_lane int default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu yönetme yetkin yok';
  end if;
  if p_lane is not null and p_lane < 1 then
    raise exception 'Kulvar numarası 1 ve üzeri olmalı';
  end if;

  update public.training_session_participants
     set lane = p_lane
   where session_id = p_session and athlete_id = p_athlete;
  if not found then
    raise exception 'Sporcu bu oturumda değil';
  end if;

  insert into public.training_session_events
    (session_id, actor_id, action, athlete_id, new_value)
  values (p_session, auth.uid(), 'lane', p_athlete,
          jsonb_build_object('lane', p_lane));
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 9) Onay ve kilit
-- ---------------------------------------------------------------------------
create or replace function public.lock_session_results(p_session uuid)
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare v_n int;
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumu onaylama yetkin yok';
  end if;

  update public.training_sets
     set locked_at = now(), locked_by = auth.uid()
   where session_id = p_session and locked_at is null;
  get diagnostics v_n = row_count;

  update public.training_sessions
     set status = 'completed',
         ended_at = coalesce(ended_at, now()),
         join_code = null
   where id = p_session;

  insert into public.training_session_events
    (session_id, actor_id, action, new_value)
  values (p_session, auth.uid(), 'lock',
          jsonb_build_object('locked_sets', v_n));

  return v_n;
end;
$fn$;

-- Kilitli sonucu düzeltmek: yalnızca yetkili antrenör, yalnızca GEREKÇEYLE,
-- eski ve yeni değer denetim izinde.
create or replace function public.correct_locked_set(
  p_set uuid,
  p_total numeric,
  p_reason text,
  p_entries jsonb default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare v_set public.training_sets%rowtype;
        v_old jsonb;
begin
  select * into v_set from public.training_sets where id = p_set;
  if not found then
    raise exception 'Set bulunamadı';
  end if;
  if not public.can_manage_training_session(v_set.session_id) then
    raise exception 'Bu sonucu düzeltme yetkin yok';
  end if;
  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'Düzeltme gerekçesi zorunlu';
  end if;

  v_old := jsonb_build_object(
    'total', v_set.total_score, 'units', v_set.unit_count,
    'entries', (select jsonb_agg(e.score order by e.seq)
                  from public.training_set_entries e where e.set_id = p_set));

  update public.training_sets
     set total_score = p_total,
         unit_count  = case
           when p_entries is null then v_set.unit_count
           else (select count(*)::int from jsonb_array_elements(p_entries) e
                  where jsonb_typeof(e.value) = 'number')
         end
   where id = p_set;

  if p_entries is not null then
    delete from public.training_set_entries where set_id = p_set;
    insert into public.training_set_entries (set_id, seq, score)
    select p_set, e.ord,
           case when jsonb_typeof(e.value) = 'number'
                then (e.value)::text::numeric end
      from jsonb_array_elements(p_entries) with ordinality as e(value, ord);
  end if;

  insert into public.training_session_events
    (session_id, actor_id, action, reason, set_no, athlete_id,
     old_value, new_value)
  values (v_set.session_id, auth.uid(), 'correct', trim(p_reason),
          v_set.set_no, v_set.athlete_id, v_old,
          jsonb_build_object('total', p_total, 'entries', p_entries));
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 10) Kişisel antrenman
--
-- Bu kayıt yalnızca sporcunun kendi geçmişinde görünüyor. Antrenör, kulüp
-- yöneticisi ve veli GÖRMÜYOR — RLS'te `kind = 'personal'` dalı.
-- ---------------------------------------------------------------------------
create or replace function public.start_personal_session(
  p_protocol uuid, p_club uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare v_athlete uuid;
        v_club    uuid;
        v_cfg     jsonb;
        v_pclub   uuid;
        v_secs    int;
        v_id      uuid;
        v_n       int;
begin
  select count(*) into v_n from public.athletes a
   where a.profile_id = auth.uid() and a.status = 'active'
     and (p_club is null or a.club_id = p_club);
  if v_n = 0 then
    raise exception 'Sporcu kaydın bulunamadı';
  end if;
  if v_n > 1 and p_club is null then
    raise exception 'Birden fazla kulüpte kaydın var, kulüp seçmelisin';
  end if;

  select a.id, a.club_id into v_athlete, v_club from public.athletes a
   where a.profile_id = auth.uid() and a.status = 'active'
     and (p_club is null or a.club_id = p_club)
   limit 1;

  select config, club_id into v_cfg, v_pclub
    from public.training_protocols where id = p_protocol;
  if v_cfg is null then
    raise exception 'Şablon bulunamadı';
  end if;
  if v_pclub is not null and v_pclub <> v_club then
    raise exception 'Bu şablon kulübüne ait değil';
  end if;

  v_secs := public.training_phase_seconds('prep', v_cfg);

  insert into public.training_sessions
    (club_id, protocol_id, kind, athlete_id, rhythm, status,
     current_set, current_phase, phase_started_at, phase_ends_at, created_by)
  values (v_club, p_protocol, 'personal', v_athlete, 'individual', 'live',
          1, 'prep', now(),
          case when coalesce(v_secs, 0) > 0
               then now() + make_interval(secs => v_secs) end,
          auth.uid())
  returning id into v_id;

  insert into public.training_session_participants (session_id, athlete_id)
  values (v_id, v_athlete);

  return jsonb_build_object('id', v_id, 'athlete_id', v_athlete);
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 11) Antrenör sonuç ekranı
--
-- SIRALAMA YOK. Sporcular arasında herkese açık bir leaderboard bilerek
-- üretilmiyor; bu satırlar yalnızca kulüp personeline dönüyor.
-- ---------------------------------------------------------------------------
create or replace function public.session_summary(p_session uuid)
returns table (
  athlete_id      uuid,
  athlete_name    text,
  lane            int,
  sets_done       int,
  sets_expected   int,
  total_score     numeric,
  avg_set         numeric,
  best_set        numeric,
  missing_sets    int,
  units_recorded  int,
  units_expected  int,
  progression     numeric[],
  score_buckets   jsonb,
  rpe             int,
  locked          boolean,
  review_flags    text[])
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumun sonuçlarını görme yetkin yok';
  end if;

  return query
  with cfg as (
    select (pr.config->>'set_count')::int     as set_count,
           (pr.config->>'units_per_set')::int as units_per_set
      from public.training_sessions s
      join public.training_protocols pr on pr.id = s.protocol_id
     where s.id = p_session
  ),
  sets as (
    select t.athlete_id,
           count(*) filter (where t.total_score is not null)::int as done,
           sum(t.total_score)                                     as total,
           avg(t.total_score)                                     as avg_set,
           max(t.total_score)                                     as best,
           sum(coalesce(t.unit_count, 0))::int                    as units,
           array_agg(t.total_score order by t.set_no)             as progression,
           bool_and(t.locked_at is not null)                      as locked
      from public.training_sets t
     where t.session_id = p_session
     group by t.athlete_id
  ),
  buckets as (
    select t.athlete_id,
           jsonb_object_agg(x.score, x.n) as buckets
      from public.training_sets t
      join lateral (
        select to_char(e.score, 'FM999999.##') as score, count(*)::int as n
          from public.training_set_entries e
         where e.set_id = t.id and e.score is not null
         group by e.score) x on true
     where t.session_id = p_session
     group by t.athlete_id
  )
  select p.athlete_id,
         (a.first_name || ' ' || a.last_name)::text,
         p.lane,
         coalesce(s.done, 0),
         c.set_count,
         s.total,
         round(s.avg_set, 2),
         s.best,
         greatest(c.set_count - coalesce(s.done, 0), 0),
         coalesce(s.units, 0),
         c.set_count * c.units_per_set,
         coalesce(s.progression, array[]::numeric[]),
         b.buckets,
         sa.rpe,
         coalesce(s.locked, false),
         (
           -- Antrenör inceleme uyarıları. Hepsi "bak" demek, "yanlış"
           -- demek değil.
           array_remove(array[
             case when coalesce(s.done, 0) = 0 then 'skor_yok' end,
             case when coalesce(s.done, 0) between 1 and c.set_count - 1
                  then 'eksik_set' end,
             case when coalesce(s.units, 0) > 0
                   and s.units < c.set_count * c.units_per_set / 2
                  then 'az_atis' end,
             case when array_length(s.progression, 1) >= 3
                   and s.progression[array_length(s.progression, 1)] is not null
                   and s.progression[array_length(s.progression, 1) - 1] is not null
                   and s.progression[array_length(s.progression, 1)]
                       < s.progression[array_length(s.progression, 1) - 1] * 0.8
                  then 'son_sette_dusus' end
           ], null)
         )::text[]
    from public.training_session_participants p
    join public.athletes a on a.id = p.athlete_id
    cross join cfg c
    left join sets s    on s.athlete_id = p.athlete_id
    left join buckets b on b.athlete_id = p.athlete_id
    left join public.training_self_assessments sa
           on sa.session_id = p_session and sa.athlete_id = p.athlete_id
   order by 2;
end;
$fn$;

create or replace function public.session_overview(p_session uuid)
returns table (
  joined_count     int,
  completed_count  int,
  no_score_count   int,
  awaiting_lock    int,
  team_total       numeric,
  session_avg      numeric,
  units_recorded   int,
  units_expected   int,
  protocol_name    text,
  protocol_version int,
  set_count        int,
  status           text)
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.can_manage_training_session(p_session) then
    raise exception 'Bu oturumun özetini görme yetkin yok';
  end if;

  return query
  with s as (select * from public.training_sessions where id = p_session),
  pr as (select p.* from public.training_protocols p
           join s on s.protocol_id = p.id),
  parts as (select count(*)::int n from public.training_session_participants
             where session_id = p_session),
  per as (
    select t.athlete_id,
           count(*) filter (where t.total_score is not null)::int as done,
           bool_and(t.locked_at is not null) as locked
      from public.training_sets t where t.session_id = p_session
     group by t.athlete_id
  ),
  agg as (
    select coalesce(sum(t.total_score), 0)          as total,
           avg(t.total_score)                       as avg_all,
           coalesce(sum(t.unit_count), 0)::int      as units
      from public.training_sets t where t.session_id = p_session
  )
  select parts.n,
         (select count(*)::int from per
           where per.done >= (pr.config->>'set_count')::int),
         parts.n - (select count(*)::int from per where per.done > 0),
         (select count(*)::int from per where not per.locked),
         agg.total,
         round(agg.avg_all, 2),
         agg.units,
         parts.n * (pr.config->>'set_count')::int
                 * (pr.config->>'units_per_set')::int,
         pr.name,
         pr.version,
         (pr.config->>'set_count')::int,
         s.status
    from s, pr, parts, agg;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 12) Sporcunun kendi geçmişi
--
-- Kulüp ve kişisel oturumlar bir arada; ikisi de YALNIZCA sporcunun
-- kendisine dönüyor.
-- ---------------------------------------------------------------------------
create or replace function public.my_training_history(p_limit int default 30)
returns table (
  session_id    uuid,
  kind          text,
  protocol_name text,
  sport_code    text,
  started_at    timestamptz,
  status        text,
  sets_done     int,
  set_count     int,
  total_score   numeric,
  best_set      numeric,
  avg_set       numeric,
  rpe           int)
language sql
stable
security definer
set search_path = public
as $fn$
  select s.id,
         s.kind,
         pr.name,
         pr.sport_code,
         s.started_at,
         s.status,
         coalesce(agg.done, 0),
         (pr.config->>'set_count')::int,
         agg.total,
         agg.best,
         round(agg.avg_set, 2),
         sa.rpe
    from public.training_sessions s
    join public.training_protocols pr on pr.id = s.protocol_id
    join public.athletes a
      on a.profile_id = auth.uid()
     and a.club_id = s.club_id
    left join lateral (
      select count(*) filter (where t.total_score is not null)::int as done,
             sum(t.total_score) as total,
             max(t.total_score) as best,
             avg(t.total_score) as avg_set
        from public.training_sets t
       where t.session_id = s.id and t.athlete_id = a.id) agg on true
    left join public.training_self_assessments sa
           on sa.session_id = s.id and sa.athlete_id = a.id
   where (s.kind = 'personal' and s.athlete_id = a.id)
      or (s.kind = 'club' and exists (
            select 1 from public.training_session_participants p
             where p.session_id = s.id and p.athlete_id = a.id))
   order by s.started_at desc
   limit greatest(coalesce(p_limit, 30), 1);
$fn$;

-- Sporcunun katıldığı canlı oturum. Ana Sayfa "Bugün" bloğu bunu soruyor.
create or replace function public.my_live_training_session()
returns table (
  session_id    uuid,
  club_id       uuid,
  kind          text,
  protocol_name text,
  current_phase text,
  current_set   int,
  set_count     int,
  phase_ends_at timestamptz,
  paused        boolean,
  rhythm        text)
language sql
stable
security definer
set search_path = public
as $fn$
  select s.id, s.club_id, s.kind, pr.name, s.current_phase, s.current_set,
         (pr.config->>'set_count')::int, s.phase_ends_at,
         s.paused_at is not null, s.rhythm
    from public.training_sessions s
    join public.training_protocols pr on pr.id = s.protocol_id
    join public.athletes a
      on a.profile_id = auth.uid() and a.club_id = s.club_id
    join public.training_session_participants p
      on p.session_id = s.id and p.athlete_id = a.id
   where s.status = 'live'
   order by s.started_at desc
   limit 1;
$fn$;

-- Antrenörün yoklama ekranındaki İPUCU: kim oturuma katıldı.
-- Bu satır yoklama İŞARETLEMİYOR — resmî yoklama mevcut güvenli akıştan.
create or replace function public.session_attendance_hint(p_event uuid)
returns table (athlete_id uuid, joined_at timestamptz)
language sql
stable
security definer
set search_path = public
as $fn$
  select p.athlete_id, p.joined_at
    from public.training_sessions s
    join public.training_session_participants p on p.session_id = s.id
   where s.event_id = p_event
     and s.kind = 'club'
     and public.is_club_staff(s.club_id);
$fn$;

-- ---------------------------------------------------------------------------
-- 13) İzinler
--
-- `PUBLIC` ayrı ele alınıyor — izin ondan miras alınıyor, yalnızca `anon`
-- ve `authenticated`'dan almak yetmiyor.
-- ---------------------------------------------------------------------------
revoke execute on function public.create_training_protocol(uuid, text, text, text, jsonb) from public, anon;
revoke execute on function public.revise_training_protocol(uuid, text, text, jsonb) from public, anon;
revoke execute on function public.start_training_session(uuid, uuid, uuid, uuid, text) from public, anon;
revoke execute on function public.join_training_session(text) from public, anon;
revoke execute on function public.advance_session_phase(uuid, text, text) from public, anon;
revoke execute on function public.set_training_pause(uuid, boolean, text) from public, anon;
revoke execute on function public.submit_set_score(uuid, int, numeric, jsonb) from public, anon;
revoke execute on function public.assign_session_lane(uuid, uuid, int) from public, anon;
revoke execute on function public.lock_session_results(uuid) from public, anon;
revoke execute on function public.correct_locked_set(uuid, numeric, text, jsonb) from public, anon;
revoke execute on function public.start_personal_session(uuid, uuid) from public, anon;
revoke execute on function public.session_summary(uuid) from public, anon;
revoke execute on function public.session_overview(uuid) from public, anon;
revoke execute on function public.my_training_history(int) from public, anon;
revoke execute on function public.my_live_training_session() from public, anon;
revoke execute on function public.session_attendance_hint(uuid) from public, anon;
revoke execute on function public.generate_join_code() from public, anon;

grant execute on function public.create_training_protocol(uuid, text, text, text, jsonb) to authenticated;
grant execute on function public.revise_training_protocol(uuid, text, text, jsonb) to authenticated;
grant execute on function public.start_training_session(uuid, uuid, uuid, uuid, text) to authenticated;
grant execute on function public.join_training_session(text) to authenticated;
grant execute on function public.advance_session_phase(uuid, text, text) to authenticated;
grant execute on function public.set_training_pause(uuid, boolean, text) to authenticated;
grant execute on function public.submit_set_score(uuid, int, numeric, jsonb) to authenticated;
grant execute on function public.assign_session_lane(uuid, uuid, int) to authenticated;
grant execute on function public.lock_session_results(uuid) to authenticated;
grant execute on function public.correct_locked_set(uuid, numeric, text, jsonb) to authenticated;
grant execute on function public.start_personal_session(uuid, uuid) to authenticated;
grant execute on function public.session_summary(uuid) to authenticated;
grant execute on function public.session_overview(uuid) to authenticated;
grant execute on function public.my_training_history(int) to authenticated;
grant execute on function public.my_live_training_session() to authenticated;
grant execute on function public.session_attendance_hint(uuid) to authenticated;
