-- =============================================================================
-- SwanSport — ŞEHİR BAZLI ANTRENÖR TOPLULUKLARI
--   1) 81 il referansı + profillere şehir
--   2) Topluluklar ve üyelik (otomatik katılım, çıkma, tekrar katılma)
--   3) Grup mesajları + anlık (realtime) yayın
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ŞEHİR REFERANSI
--
-- Serbest metin yerine referans tablo: grup üyeliği bu değere göre belirleniyor,
-- "konya" ile "Konya" iki ayrı gruba düşseydi özellik sessizce bozulurdu.
-- ---------------------------------------------------------------------------
create table if not exists public.cities (
  code text primary key,   -- plaka: '42'
  name text not null
);

alter table public.cities enable row level security;

drop policy if exists "cities_read" on public.cities;
create policy "cities_read" on public.cities for select to authenticated using (true);

insert into public.cities (code, name) values
  ('01','Adana'),('02','Adıyaman'),('03','Afyonkarahisar'),('04','Ağrı'),
  ('05','Amasya'),('06','Ankara'),('07','Antalya'),('08','Artvin'),
  ('09','Aydın'),('10','Balıkesir'),('11','Bilecik'),('12','Bingöl'),
  ('13','Bitlis'),('14','Bolu'),('15','Burdur'),('16','Bursa'),
  ('17','Çanakkale'),('18','Çankırı'),('19','Çorum'),('20','Denizli'),
  ('21','Diyarbakır'),('22','Edirne'),('23','Elazığ'),('24','Erzincan'),
  ('25','Erzurum'),('26','Eskişehir'),('27','Gaziantep'),('28','Giresun'),
  ('29','Gümüşhane'),('30','Hakkâri'),('31','Hatay'),('32','Isparta'),
  ('33','Mersin'),('34','İstanbul'),('35','İzmir'),('36','Kars'),
  ('37','Kastamonu'),('38','Kayseri'),('39','Kırklareli'),('40','Kırşehir'),
  ('41','Kocaeli'),('42','Konya'),('43','Kütahya'),('44','Malatya'),
  ('45','Manisa'),('46','Kahramanmaraş'),('47','Mardin'),('48','Muğla'),
  ('49','Muş'),('50','Nevşehir'),('51','Niğde'),('52','Ordu'),
  ('53','Rize'),('54','Sakarya'),('55','Samsun'),('56','Siirt'),
  ('57','Sinop'),('58','Sivas'),('59','Tekirdağ'),('60','Tokat'),
  ('61','Trabzon'),('62','Tunceli'),('63','Şanlıurfa'),('64','Uşak'),
  ('65','Van'),('66','Yozgat'),('67','Zonguldak'),('68','Aksaray'),
  ('69','Bayburt'),('70','Karaman'),('71','Kırıkkale'),('72','Batman'),
  ('73','Şırnak'),('74','Bartın'),('75','Ardahan'),('76','Iğdır'),
  ('77','Yalova'),('78','Karabük'),('79','Kilis'),('80','Osmaniye'),
  ('81','Düzce')
on conflict (code) do update set name = excluded.name;


alter table public.profiles
  add column if not exists city_code text references public.cities(code);


-- Kulübün serbest metin şehrinden il kodu tahmin eder (yalnızca öneri için).
-- Türkçe büyük/küçük harf ve aksan farklarını katlar; tutmazsa null döner.
create or replace function public.normalize_city(p_text text)
returns text language sql stable set search_path = public as $$
  with folded as (
    select translate(lower(trim(coalesce(p_text, ''))),
                     'çğıöşüâîû', 'cgiosuaiu') as t
  )
  select c.code
    from public.cities c, folded f
   where f.t <> ''
     and translate(lower(c.name), 'çğıöşüâîû', 'cgiosuaiu') = f.t
   limit 1;
$$;


-- ---------------------------------------------------------------------------
-- 2) TOPLULUKLAR
-- ---------------------------------------------------------------------------
create table if not exists public.communities (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null default 'city_coach',  -- ileride 'city_athlete' vb.
  city_code  text references public.cities(code),
  name       text not null,
  created_at timestamptz not null default now(),
  unique (kind, city_code)
);

alter table public.communities enable row level security;

drop policy if exists "community_read" on public.communities;
create policy "community_read" on public.communities for select
  to authenticated using (true);

-- Her il için bir antrenör grubu.
insert into public.communities (kind, city_code, name)
  select 'city_coach', c.code, c.name || ' Antrenörler' from public.cities c
on conflict (kind, city_code) do nothing;


create table if not exists public.community_members (
  community_id uuid not null references public.communities(id) on delete cascade,
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  -- 'left' satırı SİLİNMEZ: otomatik katılımın, gruptan çıkmış birini bir
  -- sonraki açılışta geri sokmasını engelleyen tek şey budur.
  state        text not null default 'joined',   -- joined | left
  joined_at    timestamptz not null default now(),
  left_at      timestamptz,
  last_read_at timestamptz not null default now(),
  primary key (community_id, profile_id)
);
create index if not exists idx_comm_member_profile
  on public.community_members (profile_id, state);

alter table public.community_members enable row level security;

-- Yazma yalnızca RPC üzerinden; doğrudan insert/update kapalı.


-- ---------------------------------------------------------------------------
-- 3) YETKİ
--
-- Politikalar bu fonksiyonlara dayandığı için önce fonksiyonlar tanımlanır.
-- ---------------------------------------------------------------------------
-- Platform düzeyinde doğrulanmış antrenör mü? (kulüpten bağımsız)
create or replace function public.is_verified_coach(p_profile uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profile_credentials c
     where c.profile_id = p_profile
       and c.kind = 'coach'
       and c.status = 'approved'
  );
$$;

create or replace function public.is_community_member(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.community_members m
     where m.community_id = p_community
       and m.profile_id = auth.uid()
       and m.state = 'joined'
  );
$$;

-- Bu topluluğa girmeye uygun mu: doğrulanmış antrenör + şehir eşleşmesi.
create or replace function public.can_join_community(p_community uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.communities c
      join public.profiles p on p.id = auth.uid()
     where c.id = p_community
       and c.kind = 'city_coach'
       and c.city_code is not distinct from p.city_code
       and p.city_code is not null
       and public.is_verified_coach()
  );
$$;


-- Üyeler birbirini görebilir (kimlerin grupta olduğu listelenebilsin).
drop policy if exists "comm_member_read" on public.community_members;
create policy "comm_member_read" on public.community_members for select
  to authenticated
  using (profile_id = auth.uid() or public.is_community_member(community_id));


-- ---------------------------------------------------------------------------
-- 4) KATILIM AKIŞI
-- ---------------------------------------------------------------------------
-- Otomatik katılım. Trigger yerine RPC: kişi şehrini değiştirdiğinde, kademesi
-- onaylandığında ve ileride yeni grup türü eklendiğinde aynı tek çağrı hepsini
-- yakalar. Daha önce "çıktım" demiş olduğu gruplara DOKUNMAZ.
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
     where c.kind = 'city_coach'
       and p.city_code is not null
       and c.city_code = p.city_code
  ), inserted as (
    insert into public.community_members (community_id, profile_id)
    select e.id, auth.uid() from eligible e
    on conflict (community_id, profile_id) do nothing
    returning 1
  )
  select count(*) into v_added from inserted;

  return v_added;
end; $$;

create or replace function public.join_community(p_community uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.can_join_community(p_community) then
    raise exception 'Bu topluluğa katılma yetkin yok';
  end if;

  insert into public.community_members (community_id, profile_id)
       values (p_community, auth.uid())
  on conflict (community_id, profile_id) do update
     set state = 'joined', joined_at = now(), left_at = null;
end; $$;

create or replace function public.leave_community(p_community uuid)
returns void language sql security definer set search_path = public as $$
  update public.community_members
     set state = 'left', left_at = now()
   where community_id = p_community and profile_id = auth.uid();
$$;


-- ---------------------------------------------------------------------------
-- 5) MESAJLAR
-- ---------------------------------------------------------------------------
create table if not exists public.community_messages (
  id           uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities(id) on delete cascade,
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now()
);
create index if not exists idx_comm_msg
  on public.community_messages (community_id, created_at);

alter table public.community_messages enable row level security;

drop policy if exists "comm_msg_read" on public.community_messages;
create policy "comm_msg_read" on public.community_messages for select
  to authenticated using (public.is_community_member(community_id));

drop policy if exists "comm_msg_send" on public.community_messages;
create policy "comm_msg_send" on public.community_messages for insert
  to authenticated
  with check (sender_id = auth.uid() and public.is_community_member(community_id));

drop policy if exists "comm_msg_delete" on public.community_messages;
create policy "comm_msg_delete" on public.community_messages for delete
  to authenticated
  using (sender_id = auth.uid() or public.is_platform_admin());

-- NOT: Topluluk mesajları bilerek `notifications` satırı AÇMAZ. Açsaydı push
-- tetikleyicisi yüzünden 40 kişilik bir grupta her mesaj 39 bildirim ve 39
-- telefon uyarısı üretirdi. Okunmamış sayısı listede rozetle gösterilir.


-- Anlık yayın: mesajlar yenilemeye gerek kalmadan ekrana düşsün.
alter table public.community_messages replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.community_messages;
exception
  when duplicate_object then null;   -- zaten eklenmiş
  when undefined_object then null;   -- publication yoksa sessizce geç
end $$;


-- ---------------------------------------------------------------------------
-- 6) LİSTE VE OKUNDU
-- ---------------------------------------------------------------------------
-- Liste ekranı tek çağrıyla dolar (my_conversations ile aynı kalıp).
-- Kişinin üyesi olduğu VE uygun olduğu (çıkmış olsa bile) gruplar döner.
-- Sütun listesi sonraki kurulumlarda genişleyebildiği için önce düşürülür:
-- `create or replace` bir fonksiyonun dönüş tipini değiştiremez.
drop function if exists public.my_communities();
create or replace function public.my_communities()
returns table (
  id           uuid,
  name         text,
  city_name    text,
  member_count int,
  last_body    text,
  last_at      timestamptz,
  unread       int,
  joined       boolean
)
language sql stable security definer set search_path = public as $$
  select
    c.id,
    c.name,
    ct.name,
    (select count(*) from public.community_members m2
      where m2.community_id = c.id and m2.state = 'joined')::int,
    (select m3.body from public.community_messages m3
      where m3.community_id = c.id
      order by m3.created_at desc limit 1),
    (select m4.created_at from public.community_messages m4
      where m4.community_id = c.id
      order by m4.created_at desc limit 1),
    (select count(*) from public.community_messages m5
      where m5.community_id = c.id
        and m5.created_at > coalesce(mem.last_read_at, 'epoch'::timestamptz)
        and m5.sender_id <> auth.uid())::int,
    coalesce(mem.state, 'left') = 'joined'
  from public.communities c
  join public.cities ct on ct.code = c.city_code
  left join public.community_members mem
         on mem.community_id = c.id and mem.profile_id = auth.uid()
  where mem.profile_id is not null          -- üyeliği var (çıkmış olsa da)
     or public.can_join_community(c.id)     -- ya da girmeye uygun
  order by coalesce(mem.state, 'left') = 'joined' desc, c.name;
$$;

create or replace function public.mark_community_read(p_community uuid)
returns void language sql security definer set search_path = public as $$
  update public.community_members
     set last_read_at = now()
   where community_id = p_community and profile_id = auth.uid();
$$;


-- Sohbette gönderenin adı/avatarı görünsün diye küçük yardımcı.
create or replace function public.community_messages_page(
  p_community uuid, p_limit int default 200)
returns table (
  id uuid, body text, created_at timestamptz,
  sender_id uuid, sender_name text, sender_avatar text
)
language sql stable security definer set search_path = public as $$
  select m.id, m.body, m.created_at,
         m.sender_id, p.full_name, p.avatar_path
    from public.community_messages m
    join public.profiles p on p.id = m.sender_id
   where m.community_id = p_community
     and public.is_community_member(p_community)
   order by m.created_at desc
   limit greatest(p_limit, 1);
$$;
