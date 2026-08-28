-- =============================================================================
-- SwanSport — FEDERASYON DUYURU KANALLARI
--
-- Şehir gruplarından temelde farklı bir şey: orada 20 kişi sohbet ediyor,
-- burada bir federasyon binlerce antrenöre sesleniyor. Bu yüzden aynı "herkes
-- yazar" modeli kullanılmaz:
--   • Ana akışa yalnızca federasyon yetkilisi yazar (duyuru).
--   • Antrenörler her duyurunun ALTINA soru sorabilir (yanıt dizisi).
--
-- Kapsam kararı: branş başına TEK ulusal kanal, ama her duyuru bir ile
-- hedeflenebilir. Böylece antrenör tek kanal takip eder; il temsilciliği de
-- yalnızca kendi iline seslenebilir. 81 il × branş kadar boş kanal açılmaz.
--
-- ÖNCE supabase/COMMUNITIES.sql çalıştırılmış olmalı.
-- Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) BRANŞ REFERANSI
-- ---------------------------------------------------------------------------
create table if not exists public.sports (
  code text primary key,
  name text not null
);

alter table public.sports enable row level security;

drop policy if exists "sports_read" on public.sports;
create policy "sports_read" on public.sports for select to authenticated using (true);

insert into public.sports (code, name) values
  ('futbol','Futbol'),('basketbol','Basketbol'),('voleybol','Voleybol'),
  ('hentbol','Hentbol'),('yuzme','Yüzme'),('atletizm','Atletizm'),
  ('gures','Güreş'),('judo','Judo'),('karate','Karate'),
  ('taekwondo','Taekwondo'),('tenis','Tenis'),('masa-tenisi','Masa Tenisi'),
  ('badminton','Badminton'),('boks','Boks'),('halter','Halter'),
  ('cimnastik','Cimnastik'),('eskrim','Eskrim'),('okculuk','Okçuluk'),
  ('bisiklet','Bisiklet'),('kurek','Kürek'),('yelken','Yelken'),
  ('triatlon','Triatlon'),('kayak','Kayak'),('buz-hokeyi','Buz Hokeyi'),
  ('muaythai','Muaythai'),('kick-boks','Kick Boks'),('bocce','Bocce'),
  ('dagcilik','Dağcılık'),('satranc','Satranç'),('binicilik','Binicilik'),
  ('su-topu','Su Topu'),('gorme-engelliler','Görme Engelliler Spor'),
  ('bedensel-engelliler','Bedensel Engelliler Spor'),
  ('ozel-sporcular','Özel Sporcular')
on conflict (code) do update set name = excluded.name;


-- Branş, kişinin beyanı değil ONAYLANMIŞ BELGESİNİN alanıdır: antrenörlük
-- belgesi zaten branşa özeldir ("Yüzme 2. Kademe"). Kişi profilinden branş
-- seçebilseydi, hiç yüzme belgesi olmayan biri Yüzme Federasyonu kanalına
-- girebilirdi.
alter table public.profile_credentials
  add column if not exists sport_code text references public.sports(code);

-- Önceki sürümde profile eklenmiş olabilir — tek doğru kaynak kalsın.
alter table public.profiles drop column if exists sport_code;


-- ---------------------------------------------------------------------------
-- 2) TOPLULUK MODELİNİ GENİŞLET
-- ---------------------------------------------------------------------------
alter table public.communities
  add column if not exists sport_code   text references public.sports(code),
  add column if not exists description  text,
  -- 'members': herkes yazar (şehir grupları)
  -- 'staff'  : ana akışa yalnızca yetkili yazar (federasyon kanalları)
  add column if not exists write_policy text not null default 'members';

-- Federasyon kanalları ulusal olduğu için city_code boş; branşa göre tekil.
create unique index if not exists idx_community_federation
  on public.communities (kind, sport_code)
  where kind = 'federation';

alter table public.community_members
  add column if not exists role text not null default 'member';  -- member | staff

alter table public.community_messages
  -- Yanıt dizisi: duyurunun altındaki sorular.
  add column if not exists parent_id uuid
      references public.community_messages(id) on delete cascade,
  -- Boş = tüm Türkiye. Dolu = yalnızca o ilin antrenörlerine.
  add column if not exists target_city_code text references public.cities(code);

create index if not exists idx_comm_msg_parent
  on public.community_messages (parent_id, created_at);


-- Her branş için bir ulusal federasyon kanalı.
insert into public.communities (kind, sport_code, name, description, write_policy)
  select 'federation', s.code, s.name || ' Federasyonu',
         s.name || ' branşındaki antrenörlere yönelik resmî duyurular.',
         'staff'
    from public.sports s
on conflict do nothing;


-- ---------------------------------------------------------------------------
-- 3) YETKİ
-- ---------------------------------------------------------------------------
-- Bu kanalda duyuru yazabilir mi? (federasyon yetkilisi ya da platform yöneticisi)
create or replace function public.is_community_staff(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_platform_admin() or exists (
    select 1 from public.community_members m
     where m.community_id = p_community
       and m.profile_id = auth.uid()
       and m.state = 'joined'
       and m.role = 'staff'
  );
$$;

-- Kişinin onaylanmış antrenörlük belgelerindeki branşlar.
create or replace function public.my_coach_sports()
returns table (sport_code text)
language sql stable security definer set search_path = public as $$
  select distinct c.sport_code
    from public.profile_credentials c
   where c.profile_id = auth.uid()
     and c.kind = 'coach'
     and c.status = 'approved'
     and c.sport_code is not null;
$$;

-- Katılım uygunluğu: şehir grubu şehre, federasyon kanalı ONAYLI BELGENİN
-- branşına bakar. Birden çok branşta belgesi olan antrenör her ikisinin de
-- kanalına girer.
create or replace function public.can_join_community(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.communities c
      join public.profiles p on p.id = auth.uid()
     where c.id = p_community
       and public.is_verified_coach()
       and (
         (c.kind = 'city_coach'
            and p.city_code is not null
            and c.city_code = p.city_code)
         or
         (c.kind = 'federation'
            and c.sport_code in (select s.sport_code from public.my_coach_sports() s))
       )
  );
$$;

-- Platform yöneticisi federasyon yetkilisi atar/alır.
create or replace function public.set_community_staff(
  p_community uuid, p_profile uuid, p_staff boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Yetkisiz';
  end if;

  -- Yetkili yapılan kişi kanala üye değilse önce üye yapılır.
  insert into public.community_members (community_id, profile_id, role)
       values (p_community, p_profile, case when p_staff then 'staff' else 'member' end)
  on conflict (community_id, profile_id) do update
     set role  = case when p_staff then 'staff' else 'member' end,
         state = 'joined',
         left_at = null;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) OTOMATİK KATILIM (şehir + federasyon)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_my_communities()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_added int := 0;
begin
  if not public.is_verified_coach() then
    return 0;
  end if;

  with eligible as (
    select c.id
      from public.communities c
      join public.profiles p on p.id = auth.uid()
     where (c.kind = 'city_coach'
              and p.city_code is not null
              and c.city_code = p.city_code)
        or (c.kind = 'federation'
              and c.sport_code in (select s.sport_code from public.my_coach_sports() s))
  ), inserted as (
    insert into public.community_members (community_id, profile_id)
    select e.id, auth.uid() from eligible e
    on conflict (community_id, profile_id) do nothing
    returning 1
  )
  select count(*) into v_added from inserted;

  return v_added;
end; $$;


-- ---------------------------------------------------------------------------
-- 5) MESAJ POLİTİKALARI
-- ---------------------------------------------------------------------------
-- Okuma: üyeyse görür; il hedefli duyuruyu yalnızca o ilin antrenörü görür.
-- Yanıtlar her zaman görünür — zaten yalnızca üstündeki duyuru üzerinden
-- erişiliyorlar.
drop policy if exists "comm_msg_read" on public.community_messages;
create policy "comm_msg_read" on public.community_messages for select
  to authenticated
  using (
    public.is_community_member(community_id)
    and (
      parent_id is not null
      or target_city_code is null
      or target_city_code = (select p.city_code from public.profiles p
                              where p.id = auth.uid())
    )
  );

-- Yazma: 'staff' kanalında ana akışa yalnızca yetkili yazar; yanıtı herkes.
drop policy if exists "comm_msg_send" on public.community_messages;
create policy "comm_msg_send" on public.community_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_community_member(community_id)
    and (
      parent_id is not null
      or coalesce((select c.write_policy from public.communities c
                    where c.id = community_id), 'members') = 'members'
      or public.is_community_staff(community_id)
    )
  );


-- ---------------------------------------------------------------------------
-- 6) DUYURU LİSTESİ VE YANITLAR
-- ---------------------------------------------------------------------------
create or replace function public.federation_announcements(
  p_community uuid, p_limit int default 100)
returns table (
  id uuid, body text, created_at timestamptz,
  sender_id uuid, sender_name text, sender_avatar text,
  city_name text, reply_count int
)
language sql stable security definer set search_path = public as $$
  select m.id, m.body, m.created_at,
         m.sender_id, p.full_name, p.avatar_path,
         ct.name,
         (select count(*) from public.community_messages r
           where r.parent_id = m.id)::int
    from public.community_messages m
    join public.profiles p on p.id = m.sender_id
    left join public.cities ct on ct.code = m.target_city_code
   where m.community_id = p_community
     and m.parent_id is null
     and public.is_community_member(p_community)
     and (m.target_city_code is null
          or m.target_city_code = (select pr.city_code from public.profiles pr
                                    where pr.id = auth.uid()))
   order by m.created_at desc
   limit greatest(p_limit, 1);
$$;

create or replace function public.message_replies(p_parent uuid)
returns table (
  id uuid, body text, created_at timestamptz,
  sender_id uuid, sender_name text, sender_avatar text
)
language sql stable security definer set search_path = public as $$
  select r.id, r.body, r.created_at, r.sender_id, p.full_name, p.avatar_path
    from public.community_messages r
    join public.profiles p on p.id = r.sender_id
    join public.community_messages parent on parent.id = r.parent_id
   where r.parent_id = p_parent
     and public.is_community_member(parent.community_id)
   order by r.created_at;
$$;


-- ---------------------------------------------------------------------------
-- 7) LİSTE — kanal türü ve yazma yetkisi de dönsün
-- ---------------------------------------------------------------------------
drop function if exists public.my_communities();
create or replace function public.my_communities()
returns table (
  id           uuid,
  name         text,
  city_name    text,
  kind         text,
  member_count int,
  last_body    text,
  last_at      timestamptz,
  unread       int,
  joined       boolean,
  can_write    boolean
)
language sql stable security definer set search_path = public as $$
  select
    c.id,
    c.name,
    coalesce(ct.name, s.name),
    c.kind,
    (select count(*) from public.community_members m2
      where m2.community_id = c.id and m2.state = 'joined')::int,
    (select m3.body from public.community_messages m3
      where m3.community_id = c.id and m3.parent_id is null
      order by m3.created_at desc limit 1),
    (select m4.created_at from public.community_messages m4
      where m4.community_id = c.id and m4.parent_id is null
      order by m4.created_at desc limit 1),
    (select count(*) from public.community_messages m5
      where m5.community_id = c.id
        and m5.created_at > coalesce(mem.last_read_at, 'epoch'::timestamptz)
        and m5.sender_id <> auth.uid())::int,
    coalesce(mem.state, 'left') = 'joined',
    (c.write_policy = 'members' or public.is_community_staff(c.id))
  from public.communities c
  left join public.cities ct on ct.code = c.city_code
  left join public.sports s  on s.code  = c.sport_code
  left join public.community_members mem
         on mem.community_id = c.id and mem.profile_id = auth.uid()
  where mem.profile_id is not null
     or public.can_join_community(c.id)
  order by coalesce(mem.state, 'left') = 'joined' desc, c.name;
$$;


-- ---------------------------------------------------------------------------
-- 8) BİLDİRİM
--
-- Grup sohbeti bildirim üretmez (her mesaj herkese bildirim = kullanılamaz
-- hale gelirdi). Federasyon DUYURUSU tam tersi: seyrek ve önemli, o yüzden
-- bildirim üretir. Yanıtlar yalnızca duyuruyu yazana bildirilir.
-- ---------------------------------------------------------------------------
create or replace function public.notify_federation_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_kind  text;
  v_name  text;
  v_from  text;
begin
  select c.kind, c.name into v_kind, v_name
    from public.communities c where c.id = new.community_id;

  if v_kind is distinct from 'federation' then
    return new;
  end if;

  select coalesce(nullif(trim(p.full_name), ''), 'Bir üye')
    into v_from from public.profiles p where p.id = new.sender_id;

  if new.parent_id is null then
    -- Duyuru: hedeflenen ildeki (ya da hedef yoksa tüm) üyelere.
    insert into public.notifications (profile_id, kind, title, body, actor_id,
                                      entity_type, entity_id)
    select m.profile_id, 'announcement', v_name,
           left(new.body, 180), new.sender_id, 'community', new.community_id
      from public.community_members m
      join public.profiles p on p.id = m.profile_id
     where m.community_id = new.community_id
       and m.state = 'joined'
       and m.profile_id <> new.sender_id
       and (new.target_city_code is null
            or p.city_code = new.target_city_code);
  else
    -- Yanıt: yalnızca duyuruyu yazana.
    insert into public.notifications (profile_id, kind, title, body, actor_id,
                                      entity_type, entity_id)
    select parent.sender_id, 'comment',
           v_from || ' duyurunu yanıtladı', left(new.body, 180),
           new.sender_id, 'community', new.community_id
      from public.community_messages parent
     where parent.id = new.parent_id
       and parent.sender_id <> new.sender_id;
  end if;

  return new;
exception
  when others then
    return new;   -- bildirim, mesajın kendisini engellemesin
end; $$;

drop trigger if exists trg_notify_federation on public.community_messages;
create trigger trg_notify_federation
  after insert on public.community_messages
  for each row execute function public.notify_federation_message();
