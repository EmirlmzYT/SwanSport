-- 0045 — Takım kanalı
--
-- Denetimin bulduğu boşluk: DM var, şehir/federasyon topluluğu var, ama
-- **takımın kendi kanalı yok** — oysa takım en doğal grup. Antrenör duyuruyu
-- ya herkese açık duyuru olarak yazıyor ya da tek tek DM atıyor.
--
-- YENİ MEKANİZMA YAZILMIYOR. `communities` + `community_members` +
-- `community_messages` üçlüsü zaten çalışıyor, canlı akıyor (0042 öncesinden
-- beri realtime publication'ında), okunmamış sayacı `last_read_at` ile
-- tutuluyor ve RLS **üyelik bazlı** (`is_community_member`). Takım kanalı
-- bunun yeni bir `kind`'ı olarak yaşıyor.

-- ---------------------------------------------------------------------------
-- 1) Topluluk bir takıma ait olabilsin
--
-- `unique (kind, city_code)` kısıtına dokunmuyoruz: takım kanallarında
-- `city_code` null ve Postgres'te NULL'lar çakışmadığı için birden fazla
-- takım kanalı sorunsuz yaşıyor. Tekilliği ayrı bir indeks sağlıyor.
-- ---------------------------------------------------------------------------
alter table public.communities
  add column if not exists team_id uuid references public.teams(id) on delete cascade;

create unique index if not exists idx_community_team_unique
  on public.communities (team_id) where team_id is not null;

comment on column public.communities.team_id is
  'Doluysa bu topluluk bir takımın kanalıdır (kind = ''team''). Şehir ve '
  'federasyon topluluklarında null.';

-- ---------------------------------------------------------------------------
-- 2) Her takımın bir kanalı olsun — yeni takımda otomatik, eskiler için dolgu
-- ---------------------------------------------------------------------------
create or replace function public.ensure_team_channel()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.communities (kind, name, team_id)
  values ('team', new.name, new.id)
  on conflict do nothing;
  return new;
end;
$fn$;

drop trigger if exists trg_ensure_team_channel on public.teams;
create trigger trg_ensure_team_channel
  after insert on public.teams
  for each row execute function public.ensure_team_channel();

-- Mevcut takımlar için dolgu. `on conflict do nothing` sayesinde migration
-- tekrar çalıştırılırsa ikinci kanal açılmıyor.
insert into public.communities (kind, name, team_id)
select 'team', t.name, t.id
  from public.teams t
 where not exists (select 1 from public.communities c where c.team_id = t.id)
on conflict do nothing;

-- Takım adı değişince kanal adı da değişsin; iki yerde ayrışmasın.
create or replace function public.sync_team_channel_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.name is distinct from old.name then
    update public.communities set name = new.name where team_id = new.id;
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_sync_team_channel_name on public.teams;
create trigger trg_sync_team_channel_name
  after update on public.teams
  for each row execute function public.sync_team_channel_name();

-- ---------------------------------------------------------------------------
-- 3) Takım kanalına katılım
--
-- `ensure_my_communities`'e EKLENMİYOR, ayrı fonksiyon. Sebep: o fonksiyon
-- `is_verified_coach()` şartına bağlı ve şehir/federasyon toplulukları için
-- doğru olan bu şart. Takım kanalında sporcunun ve kulüp görevlisinin de
-- olması gerekiyor; mevcut fonksiyonu gevşetmek onun kapısını da açardı.
-- ---------------------------------------------------------------------------
create or replace function public.ensure_my_team_channels()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_added int := 0;
begin
  if auth.uid() is null then
    return 0;
  end if;

  with eligible as (
    -- Takımdaki sporcu
    select c.id
      from public.communities c
      join public.team_memberships tm on tm.team_id = c.team_id
      join public.athletes a on a.id = tm.athlete_id
     where c.team_id is not null
       and a.profile_id = auth.uid()

    union

    -- Takımın kulübündeki görevli (antrenör, yönetici)
    select c.id
      from public.communities c
      join public.teams t on t.id = c.team_id
     where c.team_id is not null
       and public.is_club_staff(t.club_id)
  ), inserted as (
    insert into public.community_members (community_id, profile_id)
    select e.id, auth.uid() from eligible e
    on conflict (community_id, profile_id) do nothing
    returning 1
  )
  select count(*) into v_added from inserted;

  return v_added;
end;
$fn$;

revoke execute on function public.ensure_my_team_channels() from public, anon;
grant execute on function public.ensure_my_team_channels() to authenticated;

-- ---------------------------------------------------------------------------
-- 4) Takım kanalları listelenebilir olmasın
--
-- `community_read` şu ana kadar `using (true)` idi: giriş yapmış herkes bütün
-- toplulukları listeleyebiliyordu. Şehir ve federasyon toplulukları için
-- sorun değil — zaten katılmak için var. Takım kanalı için sorun: kulüplerin
-- takım adları ve yapısı dışarıya sızar.
--
-- Mesaj okuma zaten üyelik istiyordu (`is_community_member`), yani içerik
-- hiçbir zaman açık değildi; kapatılan şey kanalın **varlığı**.
-- ---------------------------------------------------------------------------
drop policy if exists "community_read" on public.communities;
create policy "community_read" on public.communities for select
  to authenticated
  using (
    team_id is null                      -- şehir / federasyon: eskisi gibi açık
    or public.is_community_member(id)    -- takım kanalı: yalnızca üyeye
    or exists (select 1 from public.teams t
                where t.id = team_id and public.is_club_staff(t.club_id))
  );
