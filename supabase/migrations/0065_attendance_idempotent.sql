-- ---------------------------------------------------------------------------
-- 0065 — Sunucu tarafı idempotent yoklama ve sürüm çakışması
--
-- ÖNCEKİ TASARIMDAN DÖNÜŞ. `docs/offline-attendance-design.md` çakışmayı
-- `marked_at` ile çözüyordu: cihazda en son işaretlenen kazanır. Plan bunu
-- açıkça reddediyor ve haklı:
--
--   • Cihaz saatleri güvenilmez; saati yanlış kurulmuş telefon hep kazanır.
--   • Sessiz ezme, iki antrenörün farklı gördüğü bir gerçeği kimseye
--     sormadan karara bağlıyor.
--
-- Yerine **iyimser sürüm kontrolü**: istemci okuduğu sürümü geri gönderiyor,
-- sürüm değişmişse yazma reddediliyor ve çakışma insana gösteriliyor.
-- Kaybolan veri yok, sessiz karar yok.
--
-- `op_id` TEK TELEFONDA DEĞİL SUNUCUDA: `(actor_id, op_id)` benzersizliği
-- burada. Cihaz verisi silinse bile aynı işlem ikinci kez yazılmıyor.
-- ---------------------------------------------------------------------------

alter table public.attendance
  add column if not exists version   int not null default 1,
  add column if not exists marked_at timestamptz,
  add column if not exists actor_id  uuid references public.profiles(id) on delete set null;

-- ---------------------------------------------------------------------------
-- İŞLEM GÜNLÜĞÜ
--
-- Sonuç `jsonb` olarak saklanıyor: aynı `op_id` ikinci kez geldiğinde işlem
-- tekrarlanmıyor, **ilk seferin sonucu** dönüyor. İkinci çağrıya "başarılı"
-- deyip hiçbir şey döndürmemek, istemcinin kaç satırın yazıldığını
-- bilememesine yol açardı.
-- ---------------------------------------------------------------------------
create table if not exists public.attendance_op_logs (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid not null references public.profiles(id) on delete cascade,
  op_id      uuid not null,
  event_id   uuid references public.events(id) on delete set null,
  club_id    uuid references public.clubs(id) on delete cascade,
  result     jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint attendance_op_unique unique (actor_id, op_id)
);

create index if not exists idx_attendance_op_event
  on public.attendance_op_logs (event_id, created_at desc);

alter table public.attendance_op_logs enable row level security;

drop policy if exists "attendance_op_read" on public.attendance_op_logs;
create policy "attendance_op_read" on public.attendance_op_logs for select
  to authenticated
  using (actor_id = auth.uid() or public.is_club_staff(club_id));
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- TOPLU YOKLAMA KAYDI
--
-- `p_marks` biçimi:
--   [{"athlete_id": "...", "status": "present", "version": 3,
--     "marked_at": "2026-09-02T10:05:00Z"}, ...]
--
-- `version` istemcinin okuduğu sürüm. Kayıt yoksa 0 gönderilir.
--
-- Dönüş:
--   {"applied": 12, "conflicts": [{...}], "replayed": false}
--
-- ÇAKIŞMA SESSİZ GEÇİLMİYOR. Uyuşmayan satır yazılmıyor ve mevcut değeriyle
-- birlikte geri dönüyor; istemci antrenöre "sen X dedin, şu an Y yazıyor"
-- diyebiliyor. Bu, tasarımın tamamının sebebi.
-- ---------------------------------------------------------------------------
create or replace function public.save_attendance_ops(
  p_event uuid,
  p_op_id uuid,
  p_marks jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club      uuid;
  v_cached    jsonb;
  v_applied   int := 0;
  v_conflicts jsonb := '[]'::jsonb;
  v_mark      jsonb;
  v_athlete   uuid;
  v_status    text;
  v_ver       int;
  v_cur_ver   int;
  v_cur_stat  text;
  v_result    jsonb;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_op_id is null then
    raise exception 'İşlem kimliği (op_id) zorunlu';
  end if;

  select club_id into v_club from public.events where id = p_event;
  if v_club is null then
    raise exception 'Etkinlik bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu kulüpte yoklama alma yetkiniz yok';
  end if;

  -- TEKRAR GÖNDERİM: ilk seferin sonucunu döndür, hiçbir şey yazma.
  select result into v_cached
    from public.attendance_op_logs
   where actor_id = auth.uid() and op_id = p_op_id;

  if v_cached is not null then
    return v_cached || jsonb_build_object('replayed', true);
  end if;

  for v_mark in select * from jsonb_array_elements(coalesce(p_marks, '[]'::jsonb))
  loop
    v_athlete := (v_mark ->> 'athlete_id')::uuid;
    v_status  := v_mark ->> 'status';
    v_ver     := coalesce((v_mark ->> 'version')::int, 0);

    select a.version, a.status::text into v_cur_ver, v_cur_stat
      from public.attendance a
     where a.event_id = p_event and a.athlete_id = v_athlete;

    if v_cur_ver is null then
      -- Kayıt yok: istemci de yok sanıyorsa yaz.
      if v_ver = 0 then
        insert into public.attendance
          (club_id, event_id, athlete_id, status, marked_at, actor_id, version)
        values (v_club, p_event, v_athlete,
                -- `status` bir enum (attendance_status); text atamak
                -- "column is of type ... but expression is of type text"
                -- hatası verir.
                v_status::public.attendance_status,
                coalesce((v_mark ->> 'marked_at')::timestamptz, now()),
                auth.uid(), 1);
        v_applied := v_applied + 1;
      else
        -- İstemci bir sürüm biliyor ama kayıt yok: arada silinmiş.
        v_conflicts := v_conflicts || jsonb_build_object(
          'athlete_id', v_athlete, 'reason', 'deleted',
          'sent_version', v_ver, 'current_version', null,
          'current_status', null);
      end if;

    elsif v_cur_ver = v_ver then
      update public.attendance
         set status = v_status::public.attendance_status,
             marked_at = coalesce((v_mark ->> 'marked_at')::timestamptz, now()),
             actor_id = auth.uid(),
             version = version + 1
       where event_id = p_event and athlete_id = v_athlete;
      v_applied := v_applied + 1;

    else
      -- SÜRÜM ÇAKIŞMASI. Yazmıyoruz; mevcut değeri geri veriyoruz.
      v_conflicts := v_conflicts || jsonb_build_object(
        'athlete_id', v_athlete, 'reason', 'version_mismatch',
        'sent_version', v_ver, 'sent_status', v_status,
        'current_version', v_cur_ver, 'current_status', v_cur_stat);
    end if;

    v_cur_ver := null;
    v_cur_stat := null;
  end loop;

  v_result := jsonb_build_object(
    'applied', v_applied,
    'conflicts', v_conflicts,
    'replayed', false);

  insert into public.attendance_op_logs
    (actor_id, op_id, event_id, club_id, result)
  values (auth.uid(), p_op_id, p_event, v_club, v_result);

  return v_result;
end;
$fn$;

revoke execute on function public.save_attendance_ops(uuid, uuid, jsonb)
  from public, anon;
grant execute on function public.save_attendance_ops(uuid, uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- SÜRÜMLÜ KADRO OKUMA
--
-- `event_roster` sürüm taşımıyordu; istemci geri gönderecek bir şey
-- bulamazdı. Yeni fonksiyon, imza değiştirmek yerine ayrı adla yazıldı —
-- `create or replace` yalnızca aynı imzayı değiştiriyor ve eski sürüm
-- kalsaydı PostgREST 300 dönerdi (AGENTS.md).
-- ---------------------------------------------------------------------------
create or replace function public.event_roster_versioned(p_event uuid)
returns table (
  athlete_id  uuid,
  full_name   text,
  status      text,
  version     int,
  rsvp_status text,
  eligibility text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select club_id into v_club from public.events where id = p_event;
  if v_club is null then
    raise exception 'Etkinlik bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu etkinliğin kadrosunu görme yetkiniz yok';
  end if;

  return query
    select a.id,
           a.first_name || ' ' || a.last_name,
           at.status::text,
           coalesce(at.version, 0),
           r.status,
           g.status
      from public.events e
      join public.team_memberships tm on tm.team_id = e.team_id
      join public.athletes a on a.id = tm.athlete_id
      left join public.attendance at
        on at.event_id = e.id and at.athlete_id = a.id
      left join public.event_rsvps r
        on r.event_id = e.id and r.athlete_id = a.id
      cross join lateral public.eligibility_gate(a.id) g
     where e.id = p_event
       and a.status = 'active'
     order by 2;
end;
$fn$;

revoke execute on function public.event_roster_versioned(uuid) from public, anon;
grant execute on function public.event_roster_versioned(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- BAYRAK
--
-- `offline_attendance` bilerek `off`. Diğerleri `admins`'te başlıyor ama bu
-- özellik yanlış çalıştığında **veri kaybettiriyor**; pilot antrenörlere
-- açılmadan önce çakışma çözme ekranı yazılmalı ve gerçek cihazda
-- denenmeli.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('offline_attendance', 'off', 'Çevrimdışı yoklama',
   'Sunucu tarafı idempotent yoklama. Çakışma çözme ekranı hazır olmadan '
   'AÇILMAMALI — yanlış çalıştığında veri kaybettirir.'),
  ('coach_workspace', 'admins', 'Antrenör çalışma alanı',
   'Antrenörün yoklama, kadro ve program işlerinin tek ekranda toplanması.')
on conflict (key) do nothing;
