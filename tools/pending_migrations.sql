-- ===========================================================================
-- SwanSport — bekleyen migration'lar, tek dosya
--
-- 0047 → 0052, numara sırasıyla. Supabase SQL Editor'e yapıştır ve çalıştır.
--
-- TEK İŞLEM: hepsi `begin`/`commit` arasında. Bir yerde hata olursa hiçbiri
-- uygulanmıyor — yarım uygulanmış şema, hiç uygulanmamış şemadan çok daha
-- zor toparlanır.
--
-- TEKRAR ÇALIŞTIRILABİLİR: hepsi `create or replace`, `if not exists` ve
-- `drop ... if exists` kullanıyor. Bir kısmını daha önce çalıştırdıysan
-- yeniden çalıştırmak zarar vermez.
--
-- İÇİNDEKİLER
--   0047  Core Loop — antrenman/duyuru/başarı bildirimleri
--         + `push_route`ta kaybolmuş 4 eşlemeyi geri getirir
--   0048  Türkçe arama (tr_fold / tr_contains) + pg_trgm indeksi
--   0049  GÜVENLİK — üç `security definer` RPC'de yetki kontrolü yoktu
--   0050  Pazaryeri şeması: mağazalar, görseller, favoriler, raporlar
--   0051  Pazaryeri RPC'leri: ilan oluşturma, durum, arama
--   0052  GÜVENLİK — engelleme uygulanmıyordu + pazaryeri bildirimleri
-- ===========================================================================

begin;


-- ---------------------------------------------------------------------------
-- 0047_core_loop.sql
-- ---------------------------------------------------------------------------

-- 0047 — Core Loop: var olan özellikler birbiriyle konuşsun
--
-- Yeni özellik eklemiyor. Ölçüldü ve şu çıktı: `notifications` tablosunda
-- 16 bildirim türü tanımlı, `push_route` bunların hepsini bir ekrana
-- eşliyor, push zinciri çalışıyor — ama **`event` ve `announcement`
-- türlerini kimse üretmiyor.** Tür var, rota var, üreten yok.
--
-- Sonucu şu: antrenör antrenman oluşturuyor, kimsenin haberi olmuyor.
-- Duyuru yayınlıyor, kimsenin haberi olmuyor. Sporcu başarı kazanıyor
-- (0046'dan beri otomatik), kendi bile bilmiyor.
--
-- Döngünün eksik ilk halkası buydu:
--
--   antrenman oluşturulur → [BİLDİRİM YOK] → RSVP → yoklama → performans
--
-- RSVP'yi kimse vermiyor çünkü antrenmanın varlığından haberi yok.

-- ---------------------------------------------------------------------------
-- Ortak yardımcı: bir etkinliğin/kulübün ilgili kişileri
--
-- "Kime haber verilecek" sorusu üç tetikleyicide de aynı biçimde soruluyor;
-- üç kez yazmak üçünün zamanla ayrışması demekti.
--
-- Veliler dahil: denetimde veli deneyiminin kopuk olduğu çıkmıştı — çocuğun
-- antrenmanından velinin haberi olmaması bunun en görünür hâli.
-- ---------------------------------------------------------------------------
create or replace function public.event_audience(p_event uuid)
returns table (profile_id uuid)
language sql
stable
security definer
set search_path = public
as $fn$
  with ev as (select * from public.events where id = p_event),
  ath as (
    select a.id, a.profile_id
      from ev, public.athletes a
     where a.club_id = ev.club_id
       and (
         -- Takıma bağlı etkinlik yalnızca o takıma; bağsızsa kulübün tamamına.
         ev.team_id is null
         or exists (select 1 from public.team_memberships tm
                     where tm.team_id = ev.team_id and tm.athlete_id = a.id)
       )
  )
  select profile_id from ath where profile_id is not null
  union
  select g.profile_id
    from public.guardians g
    join ath on ath.id = g.athlete_id
   where g.profile_id is not null;
$fn$;

-- ---------------------------------------------------------------------------
-- 1) Antrenman/maç oluşturulunca ilgililere haber
--
-- Yalnızca INSERT'te: her düzenlemede yeniden bildirim atmak, saatini iki kez
-- düzelten antrenörün takımı üç kez rahatsız etmesi demekti. Saat değişimi
-- ayrı bir bildirim türü hak ediyor; o ayrı bir iş.
--
-- Geçmiş tarihli etkinlik bildirim üretmiyor: kayıt tutmak için geriye dönük
-- girilen antrenmanlar var ve onlar için haber vermek anlamsız.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_when text;
begin
  if new.starts_at < now() then
    return new;
  end if;

  v_when := to_char(new.starts_at at time zone 'Europe/Istanbul',
                    'DD.MM HH24:MI');

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select a.profile_id,
         'event',
         case new.kind
           when 'match' then 'Yeni maç: ' || new.title
           else 'Yeni antrenman: ' || new.title
         end,
         v_when || coalesce(' · ' || new.place, ''),
         null,
         'event',
         new.id
    from public.event_audience(new.id) a
   -- Kendi oluşturduğun etkinlik için sana bildirim gitmesin.
   where a.profile_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_event on public.events;
create trigger trg_notify_new_event
  after insert on public.events
  for each row execute function public.notify_new_event();

-- ---------------------------------------------------------------------------
-- 2) Duyuru yayınlanınca kulübe haber
--
-- `announcement` türü ve `/announcements` rotası 0026'dan beri tanımlı;
-- eksik olan yalnızca üreten taraftı.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select m.profile_id,
         'announcement',
         new.title,
         left(coalesce(new.body, ''), 140),
         new.author_id,
         'announcement',
         new.id
    from public.club_memberships m
   where m.club_id = new.club_id
     and m.status = 'active'
     and m.profile_id <> coalesce(new.author_id,
           '00000000-0000-0000-0000-000000000000'::uuid);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_announcement on public.announcements;
create trigger trg_notify_new_announcement
  after insert on public.announcements
  for each row execute function public.notify_new_announcement();

-- ---------------------------------------------------------------------------
-- 3) Kazanılan başarı sporcuya (ve velisine) bildirilsin
--
-- 0046 başarıları otomatik üretmeye başladı ama sessizce: sporcu profiline
-- girip bakmadıkça hedefini tutturduğunu öğrenemiyordu. Gelişim döngüsünün
-- kullanıcıya dönen tek anı bu — sessiz kalması onu görünmez yapıyordu.
--
-- Yalnızca **otomatik** başarılarda (`source is not null`). Antrenörün elle
-- girdiği derece zaten konuşularak biliniyor; onu bildirmek gereksiz.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_achievement()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.source is null then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select p.profile_id,
         'achievement',
         'Yeni başarı: ' || new.title,
         coalesce(new.note, ''),
         'achievement',
         new.id
    from (
      select a.profile_id from public.athletes a where a.id = new.athlete_id
      union
      select g.profile_id from public.guardians g
       where g.athlete_id = new.athlete_id
    ) p
   where p.profile_id is not null;

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_achievement on public.athlete_achievements;
create trigger trg_notify_new_achievement
  after insert on public.athlete_achievements
  for each row execute function public.notify_new_achievement();

-- ---------------------------------------------------------------------------
-- 4) Yeni türün rotası
--
-- `push_route` bildirime dokununca hangi ekranın açılacağını söylüyor.
--
-- DİKKAT — bu fonksiyon her yeniden yazıldığında eşleme kaybediliyor.
-- Ölçüldü: 0022 `payment → /finans`, `attendance_reminder → /attendance` ve
-- `donation → /bagis` eşlemelerini eklemişti; 0039 fonksiyonu baştan yazarken
-- bu üçünü **düşürmüş**. Yani bugün canlıda ödeme bildirimine dokunan
-- kullanıcı finansa değil bildirim listesine gidiyor ve bu kimseye hata
-- gibi görünmüyor — sadece yanlış yere götürüyor.
--
-- Bu sürüm geçmişteki bütün eşlemeleri geri getiriyor. Bir dahaki sefere
-- yeniden yazan: önce `grep -rn "when '" supabase/migrations/*push*.sql`
-- ile eskileri topla.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    else '/bildirimler'
  end;
$fn$;

revoke execute on function public.event_audience(uuid) from public, anon;
grant execute on function public.event_audience(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 0048_tr_search.sql
-- ---------------------------------------------------------------------------

-- 0048 — Türkçe arama normalizasyonu (veritabanı tarafı)
--
-- Uygulama tarafında `trFold`/`trContains` (swansport_core) var ve on iki
-- dosya ona geçirildi. Ama istemci yalnızca **çekilmiş** listeyi süzebiliyor;
-- sorgu veritabanında yapılıyorsa oradaki karşılığı da olmalı. Pazaryeri
-- araması binlerce ilan arasından süzecek, istemcide filtrelemek mümkün değil.
--
-- SORUN: `lower()` Türkçe harfleri olduğu gibi bırakıyor.
--
--   lower('Işıklar')                    -> 'ışıklar'
--   lower('Işıklar') like '%isiklar%'   -> false
--
-- Kullanıcı "isiklar" yazıyor, "Işıklar Kort" bulunmuyor.
--
-- `unaccent` eklentisi bu işi görmüyor: Türkçe'de `ı` ile `i` ayrı harfler,
-- aksan değil. Eşleme elle yazılıyor.

-- ---------------------------------------------------------------------------
-- Arama için metni sadeleştirir.
--
-- `translate` ÖNCE, `lower` SONRA: bazı yerelleştirmelerde `lower('İ')`
-- birleşik noktalı bir dizi üretiyor ve sonrasında hiçbir eşleme tutmuyor.
-- Büyük Türkçe harfleri kendimiz karşılığına çevirip geri kalanı `lower`'a
-- bırakınca bu tuzağa hiç girilmiyor.
--
-- IMMUTABLE olmak zorunda: indeks ifadelerinde kullanılacak. `translate` ve
-- `lower` ikisi de immutable, o yüzden sorun yok.
-- ---------------------------------------------------------------------------
create or replace function public.tr_fold(p_text text)
returns text
language sql
immutable
strict
parallel safe
as $fn$
  select lower(translate(p_text,
    'ıİşŞğĞüÜöÖçÇâÂîÎûÛ',
    'iisSgGuUoOcCaaiiuu'));
$fn$;

comment on function public.tr_fold(text) is
  'Aramada karşılaştırmak için Türkçe metni sadeleştirir. '
  'swansport_core/text/tr_text.dart içindeki trFold ile aynı davranış — '
  'ikisi ayrışırsa istemci ve sunucu farklı sonuç verir.';

-- ---------------------------------------------------------------------------
-- `x` içinde `y` geçiyor mu — Türkçe duyarsız.
--
-- Boş arama her şeyi eşler; çağıran tarafta ayrıca kontrol gerekmesin.
-- ---------------------------------------------------------------------------
create or replace function public.tr_contains(p_haystack text, p_needle text)
returns boolean
language sql
immutable
parallel safe
as $fn$
  select coalesce(p_needle, '') = ''
      or public.tr_fold(coalesce(p_haystack, ''))
         like '%' || public.tr_fold(p_needle) || '%';
$fn$;

-- ---------------------------------------------------------------------------
-- Mevcut arama yapılan alanlarda indeks
--
-- `pg_trgm` olmadan `like '%...%'` indeks kullanamıyor. Eklenti Supabase'de
-- mevcut; onunla `gin` indeksi ortadaki eşleşmeleri de hızlandırıyor.
--
-- Şimdilik yalnızca ilan başlığı: pazaryeri araması buradan geçecek ve
-- listelerin en büyüğü o olacak. Diğer tablolar küçük; indeks eklemek
-- yazma maliyeti getirir, kazancı getirmez.
-- ---------------------------------------------------------------------------
create extension if not exists pg_trgm;

create index if not exists idx_listings_title_trfold
  on public.listings using gin (public.tr_fold(title) gin_trgm_ops);

revoke execute on function public.tr_fold(text) from public;
grant execute on function public.tr_fold(text) to anon, authenticated;
revoke execute on function public.tr_contains(text, text) from public;
grant execute on function public.tr_contains(text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 0049_rpc_authorization.sql
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- 0050_marketplace.sql
-- ---------------------------------------------------------------------------

-- 0050 — Spor malzemeleri pazaryeri: şema, görseller, favoriler, raporlar
--
-- MEVCUT YAPI KORUNUYOR. `listings` tablosu sporcu, antrenör, kulüp ve seçme
-- ilanlarını taşıyor; 0034 malzeme ilanlarını ekledi. Bu migration o tabloyu
-- **genişletiyor**, ikinci bir ilan sistemi kurmuyor. Eski ilanlar ve
-- `create_listing` RPC'si aynen çalışmaya devam ediyor.
--
-- İlk sürümde ödeme, escrow, komisyon, kargo entegrasyonu ve iade YOK.
-- Alıcı ve satıcı mevcut DM sistemiyle anlaşıyor; buradaki iş ilan, güvenlik,
-- teslim tercihi, mağaza doğrulaması ve moderasyon altyapısı.

-- ===========================================================================
-- 1) MAĞAZALAR
-- ===========================================================================
create table if not exists public.stores (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  slug          text unique,
  logo_path     text,                  -- Storage yolu; URL değil
  description   text,
  city_code     text references public.cities(code),
  district      text,

  status        text not null default 'pending',
  -- pending | approved | rejected | suspended

  applied_at    timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null,
  application_note text,               -- başvuranın notu
  review_note      text,               -- yöneticinin kararı (başvurana görünür)

  -- Kurum bilgisi ilk sürümde toplanmıyor. Gerekirse buraya eklenecek ve
  -- YALNIZCA platform yöneticisine açılacak; mağaza profilinde ve genel API
  -- yanıtlarında hiçbir zaman görünmeyecek.
  created_at    timestamptz not null default now(),

  constraint stores_status_valid
    check (status in ('pending', 'approved', 'rejected', 'suspended'))
);

create index if not exists idx_stores_status on public.stores (status);
create index if not exists idx_stores_city   on public.stores (city_code);

create table if not exists public.store_memberships (
  store_id   uuid not null references public.stores(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'owner',   -- owner | manager
  created_at timestamptz not null default now(),
  primary key (store_id, profile_id),
  constraint store_role_valid check (role in ('owner', 'manager'))
);

create index if not exists idx_store_member_profile
  on public.store_memberships (profile_id);

-- Bu kişi mağazayı yönetiyor mu — `is_turf_manager` (0038) ile aynı desen.
create or replace function public.is_store_manager(p_store uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.store_memberships m
     where m.store_id = p_store and m.profile_id = auth.uid());
$$;

-- Mağaza **onaylı** mı ve bu kişi yönetiyor mu. Sıfır ürün ilanının şartı.
create or replace function public.can_sell_new(p_store uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.stores s
     join public.store_memberships m on m.store_id = s.id
    where s.id = p_store
      and s.status = 'approved'
      and m.profile_id = auth.uid());
$$;

alter table public.stores enable row level security;
alter table public.store_memberships enable row level security;

-- Onaylı mağazalar herkese görünür; bekleyen/reddedilen yalnızca sahibine ve
-- platform yöneticisine. Reddedilmiş bir mağazanın adının arama sonucunda
-- çıkması hem yanıltıcı hem başvurana karşı haksız olurdu.
drop policy if exists "stores_read" on public.stores;
create policy "stores_read" on public.stores for select
  to authenticated
  using (
    status = 'approved'
    or public.is_store_manager(id)
    or public.is_platform_admin()
  );

-- Başvuru: kişi kendi adına mağaza açabilir, ama durumu değiştiremez.
drop policy if exists "stores_apply" on public.stores;
create policy "stores_apply" on public.stores for insert
  to authenticated with check (status = 'pending');

drop policy if exists "stores_admin" on public.stores;
create policy "stores_admin" on public.stores for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Yönetici kendi mağazasının profilini düzenleyebilir; `status` alanına
-- dokunamaması tetikleyiciyle korunuyor (aşağıda).
drop policy if exists "stores_manage" on public.stores;
create policy "stores_manage" on public.stores for update
  to authenticated
  using (public.is_store_manager(id))
  with check (public.is_store_manager(id));

create or replace function public.guard_store_status()
returns trigger language plpgsql security definer set search_path = public
as $fn$
begin
  -- Yalnızca platform yöneticisi durumu değiştirebilir. RLS `update`'e izin
  -- veriyor ama hangi sütuna dokunulduğunu göremiyor; kontrol burada.
  if new.status is distinct from old.status
     and not public.is_platform_admin() then
    raise exception 'Mağaza durumunu yalnızca platform yöneticisi değiştirir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_guard_store_status on public.stores;
create trigger trg_guard_store_status
  before update on public.stores
  for each row execute function public.guard_store_status();

drop policy if exists "store_member_read" on public.store_memberships;
create policy "store_member_read" on public.store_memberships for select
  to authenticated
  using (profile_id = auth.uid()
         or public.is_store_manager(store_id)
         or public.is_platform_admin());

drop policy if exists "store_member_admin" on public.store_memberships;
create policy "store_member_admin" on public.store_memberships for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ===========================================================================
-- 2) İLAN GENİŞLETMESİ
--
-- Yalnızca pazaryeri ilanlarında dolu olacak alanlar. Eski ilanlarda hepsi
-- null kalıyor ve hiçbir davranış değişmiyor.
-- ===========================================================================
alter table public.listings
  add column if not exists seller_type   text,      -- individual | verified_store
  add column if not exists store_id      uuid references public.stores(id) on delete cascade,
  add column if not exists item_condition text,     -- new | like_new | very_good | good | used
  add column if not exists defect_note   text,
  add column if not exists category      text,
  add column if not exists subcategory   text,
  add column if not exists brand         text,
  add column if not exists model         text,
  add column if not exists size_label    text,
  add column if not exists color         text,
  add column if not exists negotiable    boolean not null default false,
  add column if not exists stock         int,
  add column if not exists delivery      text,      -- hand_delivery | shipping | both
  add column if not exists market_status text;      -- yaşam döngüsü

do $$ begin
  alter table public.listings add constraint listings_seller_type_valid
    check (seller_type is null or seller_type in ('individual', 'verified_store'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_condition_valid
    check (item_condition is null or item_condition in
           ('new', 'like_new', 'very_good', 'good', 'used'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_delivery_valid
    check (delivery is null or delivery in ('hand_delivery', 'shipping', 'both'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_market_status_valid
    check (market_status is null or market_status in
           ('draft', 'active', 'reserved', 'sold',
            'removed_by_owner', 'under_review', 'hidden_by_moderation'));
exception when duplicate_object then null; end $$;

-- Sıfır ürün yalnızca mağazadan. Kural istemcide de gösteriliyor ama asıl
-- yeri burası: doğrudan tablo erişimiyle atlatılamamalı.
do $$ begin
  alter table public.listings add constraint listings_new_needs_store
    check (item_condition is distinct from 'new'
           or seller_type = 'verified_store');
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_store_type_match
    check ((seller_type = 'verified_store') = (store_id is not null)
           or seller_type is null);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_stock_sane
    check (stock is null or stock >= 0);
exception when duplicate_object then null; end $$;

create index if not exists idx_listings_market
  on public.listings (market_status, sport_code, city_code)
  where market_status is not null;

create index if not exists idx_listings_store
  on public.listings (store_id) where store_id is not null;

-- ===========================================================================
-- 3) GÖRSELLER — ilan başına en fazla 8
-- ===========================================================================
create table if not exists public.listing_images (
  id         uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  image_path text not null,            -- Storage yolu; URL üretimi istemcide
  sort_order int not null default 0,
  created_at timestamptz not null default now(),

  constraint listing_image_order_range check (sort_order between 0 and 7),
  unique (listing_id, sort_order)
);

create index if not exists idx_listing_images
  on public.listing_images (listing_id, sort_order);

-- Sınır veritabanı seviyesinde. `sort_order` 0-7 tek başına yetmiyor: aynı
-- sıraya iki kayıt `unique` ile engelleniyor ama sekiz satır sonrası dokuzuncu
-- bir sıra numarası olmadan da eklenebilirdi.
create or replace function public.guard_listing_image_count()
returns trigger language plpgsql security definer set search_path = public
as $fn$
begin
  if (select count(*) from public.listing_images
       where listing_id = new.listing_id) >= 8 then
    raise exception 'Bir ilanda en fazla 8 görsel olabilir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_guard_listing_image_count on public.listing_images;
create trigger trg_guard_listing_image_count
  before insert on public.listing_images
  for each row execute function public.guard_listing_image_count();

-- Eski tek görselli ilanların `image_path` verisi ilk görsel olarak taşınıyor.
-- `listings.image_path` sütunu KALDIRILMIYOR: eski ekranlar ve
-- `create_listing` RPC'si onu okumaya devam ediyor.
insert into public.listing_images (listing_id, image_path, sort_order)
select l.id, l.image_path, 0
  from public.listings l
 where l.image_path is not null
   and not exists (select 1 from public.listing_images i
                    where i.listing_id = l.id)
on conflict do nothing;

alter table public.listing_images enable row level security;

drop policy if exists "listing_image_read" on public.listing_images;
create policy "listing_image_read" on public.listing_images for select
  to anon, authenticated using (true);

drop policy if exists "listing_image_write" on public.listing_images;
create policy "listing_image_write" on public.listing_images for all
  to authenticated
  using (exists (select 1 from public.listings l
                  where l.id = listing_id
                    and (l.owner_id = auth.uid()
                         or (l.store_id is not null
                             and public.is_store_manager(l.store_id)))))
  with check (exists (select 1 from public.listings l
                       where l.id = listing_id
                         and (l.owner_id = auth.uid()
                              or (l.store_id is not null
                                  and public.is_store_manager(l.store_id)))));

-- ===========================================================================
-- 4) FAVORİLER
-- ===========================================================================
create table if not exists public.marketplace_favorites (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, listing_id)
);

create index if not exists idx_fav_listing
  on public.marketplace_favorites (listing_id);

alter table public.marketplace_favorites enable row level security;

-- Kullanıcı yalnızca kendi favorilerini görür ve yönetir. Bir ilanın kaç kez
-- favorilendiği satıcıya bile gösterilmiyor: az favorili ilan satıcıyı
-- fiyat kırmaya iter, çok favorili ilan alıcıyı acele ettirir. İkisi de
-- ilk sürümde istemediğimiz baskılar.
drop policy if exists "fav_own" on public.marketplace_favorites;
create policy "fav_own" on public.marketplace_favorites for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ===========================================================================
-- 5) RAPORLAR
-- ===========================================================================
create table if not exists public.marketplace_reports (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason      text not null,
  -- counterfeit | wrong_description | prohibited | spam | inappropriate | other
  note        text,

  status      text not null default 'open',   -- open|reviewing|resolved|dismissed
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_note text,
  created_at  timestamptz not null default now(),

  -- Aynı kullanıcı aynı ilanı bir kez raporlar.
  unique (listing_id, reporter_id),

  constraint report_reason_valid check (reason in
    ('counterfeit','wrong_description','prohibited','spam','inappropriate','other')),
  constraint report_status_valid check (status in
    ('open','reviewing','resolved','dismissed'))
);

create index if not exists idx_report_open
  on public.marketplace_reports (status, created_at desc);

alter table public.marketplace_reports enable row level security;

drop policy if exists "report_create" on public.marketplace_reports;
create policy "report_create" on public.marketplace_reports for insert
  to authenticated with check (reporter_id = auth.uid() and status = 'open');

-- Raporlayan kendi raporunu görür; kararı takip edebilsin.
drop policy if exists "report_read" on public.marketplace_reports;
create policy "report_read" on public.marketplace_reports for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_platform_admin());

drop policy if exists "report_admin" on public.marketplace_reports;
create policy "report_admin" on public.marketplace_reports for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ===========================================================================
-- 6) GÖRÜNÜRLÜK
--
-- Mevcut `listing_read` politikası `using (true)`: bütün ilanlar herkese.
-- Eski ilan türleri için doğru, ama pazaryerinde taslak, incelemedeki ve
-- moderasyonla gizlenmiş ilanlar genel akışta görünmemeli.
-- ===========================================================================
drop policy if exists "listing_read" on public.listings;
create policy "listing_read" on public.listings for select
  to authenticated
  using (
    -- Pazaryeri dışındaki ilanlar: eskisi gibi açık.
    market_status is null
    -- Pazaryeri: yalnızca yayında olanlar. Rezerve ve satıldı da görünüyor;
    -- alıcı "bu ilana ne oldu" sorusunun cevabını bulabilmeli.
    or market_status in ('active', 'reserved', 'sold')
    -- Sahibi ve mağaza yöneticisi kendi taslağını görür.
    or owner_id = auth.uid()
    or (store_id is not null and public.is_store_manager(store_id))
    or public.is_platform_admin()
  );

-- ---------------------------------------------------------------------------
-- 0051_marketplace_rpc.sql
-- ---------------------------------------------------------------------------

-- 0051 — Pazaryeri işlemleri
--
-- `create_listing` (0034) genişletilmedi, ayrı RPC yazıldı. Sebep iki tane:
--
--   1. O fonksiyon zaten 19 parametreli ve pazaryeri 12 alan daha getiriyor.
--      31 parametreli bir fonksiyonu doğru çağırmak imkânsıza yakın.
--   2. Geriye uyumluluk şartı: sporcu/iş/organizasyon ilanları ve o RPC'nin
--      mevcut çağrıları hiç etkilenmemeli. İmza değiştirmek 0034'ün kendi
--      yorumunda anlatılan `HTTP 300` tuzağını da geri getirirdi.
--
-- Ortak olan tek şey `listings` tablosu; iş mantıkları farklı.

-- ---------------------------------------------------------------------------
-- Pazaryeri ilanı oluştur
-- ---------------------------------------------------------------------------
create or replace function public.create_market_listing(
  p_title       text,
  p_body        text default null,
  p_store       uuid default null,
  p_sport       text default null,
  p_category    text default null,
  p_subcategory text default null,
  p_brand       text default null,
  p_model       text default null,
  p_size        text default null,
  p_color       text default null,
  p_condition   text default 'used',
  p_defect_note text default null,
  p_price       numeric default null,
  p_negotiable  boolean default false,
  p_stock       int default 1,
  p_delivery    text default 'hand_delivery',
  p_city        text default null,
  p_district    text default null,
  p_publish     boolean default true)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id     uuid;
  v_seller text;
  v_recent int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(p_title), '') = '' then
    raise exception 'İlan başlığı boş olamaz';
  end if;

  -- ---- Satıcı türü ve yetkisi -------------------------------------------
  if p_store is not null then
    if not public.can_sell_new(p_store) then
      raise exception 'Bu mağaza adına ilan veremezsin (mağaza onaylı değil '
                      'ya da yöneticisi değilsin)';
    end if;
    v_seller := 'verified_store';
  else
    -- Bireysel satıcı yalnızca ikinci el yayınlayabilir.
    if p_condition = 'new' then
      raise exception 'Sıfır ürün yalnızca onaylı mağazalar tarafından '
                      'yayınlanabilir';
    end if;

    -- Kimlik doğrulaması: 0034'teki kural pazaryerinde de geçerli.
    if not public.has_approved_credential() then
      raise exception 'İlan verebilmek için onaylanmış bir belgen olmalı';
    end if;

    -- Hız sınırı: 24 saatte 5 ilan. Mağazalara uygulanmıyor; gerçek stoklu
    -- bir mağazanın günde beş üründen fazla yüklemesi normal.
    select count(*) into v_recent
      from public.listings
     where owner_id = auth.uid()
       and market_status is not null
       and store_id is null
       and created_at > now() - interval '24 hours';

    if v_recent >= 5 then
      raise exception 'Günde en fazla 5 ilan verebilirsin. Yarın tekrar dene.';
    end if;

    v_seller := 'individual';
  end if;

  -- ---- Tutarlılık --------------------------------------------------------
  if p_price is not null and p_price < 0 then
    raise exception 'Fiyat negatif olamaz';
  end if;

  insert into public.listings (
    kind, owner_id, title, body, sport_code, city_code, district,
    price, seller_type, store_id, item_condition, defect_note,
    category, subcategory, brand, model, size_label, color,
    negotiable, stock, delivery, market_status, status
  ) values (
    'equipment_sale',
    auth.uid(),
    trim(p_title),
    nullif(trim(coalesce(p_body, '')), ''),
    p_sport, p_city, p_district,
    p_price, v_seller, p_store, p_condition,
    nullif(trim(coalesce(p_defect_note, '')), ''),
    p_category, p_subcategory, p_brand, p_model, p_size, p_color,
    coalesce(p_negotiable, false),
    -- Bireysel ilanda stok her zaman 1: ikinci el ürün tektir ve stok alanı
    -- girdirmek kullanıcıyı anlamsız bir soruya maruz bırakır.
    case when v_seller = 'individual' then 1 else greatest(coalesce(p_stock, 1), 0) end,
    coalesce(p_delivery, 'hand_delivery'),
    case when p_publish then 'active' else 'draft' end,
    'open'
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- İlan durumu değiştir — rezerve / satıldı / kaldır / yeniden yayınla
--
-- Ayrı RPC çünkü kimin neyi değiştirebileceği burada tek yerde duruyor.
-- Doğrudan `update` ile de yapılabilirdi ama o zaman "moderasyonla gizlenmiş
-- ilanı sahibi yeniden açabilir mi" sorusunun cevabı RLS'e gömülü kalırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_market_listing_status(
  p_listing uuid,
  p_status  text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_owner uuid;
  v_store uuid;
  v_cur   text;
begin
  select owner_id, store_id, market_status
    into v_owner, v_store, v_cur
    from public.listings where id = p_listing;

  if v_owner is null then
    raise exception 'İlan bulunamadı';
  end if;

  if not (v_owner = auth.uid()
          or (v_store is not null and public.is_store_manager(v_store))
          or public.is_platform_admin()) then
    raise exception 'Bu ilanı değiştirme yetkin yok';
  end if;

  -- Sahibinin kullanabileceği durumlar. `under_review` ve
  -- `hidden_by_moderation` yalnızca platform yöneticisinin.
  if p_status not in ('draft', 'active', 'reserved', 'sold', 'removed_by_owner')
     and not public.is_platform_admin() then
    raise exception 'Geçersiz durum';
  end if;

  -- Moderasyonla gizlenmiş ilanı sahibi geri açamaz; açabilseydi moderasyon
  -- kararının hiçbir anlamı kalmazdı.
  if v_cur = 'hidden_by_moderation' and not public.is_platform_admin() then
    raise exception 'Bu ilan moderasyon tarafından gizlendi';
  end if;

  update public.listings
     set market_status = p_status,
         status = case when p_status = 'sold' then 'closed' else 'open' end
   where id = p_listing;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Pazaryeri araması
--
-- Sayfalama `(created_at, id)` çifti üzerinden: `offset` kullanmak, arada yeni
-- ilan eklenince sayfa sınırında ilan atlatıyor ya da tekrarlatıyor.
--
-- Arama `tr_contains` (0048) ile: kullanıcı "isiklar" yazınca "Işıklar"
-- bulunmalı.
-- ---------------------------------------------------------------------------
create or replace function public.search_market_listings(
  p_query      text default null,
  p_sport      text default null,
  p_category   text default null,
  p_city       text default null,
  p_district   text default null,
  p_condition  text default null,
  p_delivery   text default null,
  p_seller     text default null,      -- individual | verified_store
  p_brand      text default null,
  p_min_price  numeric default null,
  p_max_price  numeric default null,
  p_sort       text default 'new',     -- new | price_asc | price_desc
  p_after_at   timestamptz default null,
  p_after_id   uuid default null,
  p_limit      int default 20)
returns table (
  id            uuid,
  title         text,
  price         numeric,
  item_condition text,
  seller_type   text,
  store_id      uuid,
  store_name    text,
  city_code     text,
  district      text,
  delivery      text,
  market_status text,
  image_path    text,
  created_at    timestamptz)
language sql
stable
security definer
set search_path = public
as $fn$
  select l.id, l.title, l.price, l.item_condition, l.seller_type,
         l.store_id, s.name,
         l.city_code, l.district, l.delivery, l.market_status,
         (select i.image_path from public.listing_images i
           where i.listing_id = l.id
           order by i.sort_order limit 1),
         l.created_at
    from public.listings l
    left join public.stores s on s.id = l.store_id
   where l.market_status in ('active', 'reserved', 'sold')
     and (p_query     is null or public.tr_contains(l.title, p_query)
                              or public.tr_contains(coalesce(l.brand, ''), p_query))
     and (p_sport     is null or l.sport_code = p_sport)
     and (p_category  is null or l.category = p_category)
     and (p_city      is null or l.city_code = p_city)
     and (p_district  is null or l.district = p_district)
     and (p_condition is null or l.item_condition = p_condition)
     and (p_delivery  is null or l.delivery = p_delivery or l.delivery = 'both')
     and (p_seller    is null or l.seller_type = p_seller)
     and (p_brand     is null or public.tr_contains(coalesce(l.brand, ''), p_brand))
     and (p_min_price is null or l.price >= p_min_price)
     and (p_max_price is null or l.price <= p_max_price)
     -- İmleç: yalnızca "en yeni" sıralamasında anlamlı; fiyat sıralamasında
     -- istemci sayfa numarası yerine tam listeyi daraltarak ilerliyor.
     and (p_after_at is null
          or (l.created_at, l.id) < (p_after_at, p_after_id))
   order by
     case when p_sort = 'price_asc'  then l.price end asc nulls last,
     case when p_sort = 'price_desc' then l.price end desc nulls last,
     l.created_at desc, l.id desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$fn$;

revoke execute on function public.create_market_listing(
  text,text,uuid,text,text,text,text,text,text,text,text,text,
  numeric,boolean,int,text,text,text,boolean) from public, anon;
grant execute on function public.create_market_listing(
  text,text,uuid,text,text,text,text,text,text,text,text,text,
  numeric,boolean,int,text,text,text,boolean) to authenticated;

revoke execute on function public.set_market_listing_status(uuid, text) from public, anon;
grant execute on function public.set_market_listing_status(uuid, text) to authenticated;

-- Arama giriş yapmamış kullanıcıya da açık: pazaryerinin çekim gücü
-- görünür olmasına bağlı, mevcut ilan politikasıyla da tutarlı.
revoke execute on function public.search_market_listings(
  text,text,text,text,text,text,text,text,text,numeric,numeric,text,
  timestamptz,uuid,int) from public;
grant execute on function public.search_market_listings(
  text,text,text,text,text,text,text,text,text,numeric,numeric,text,
  timestamptz,uuid,int) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 0052_blocking_and_market_notify.sql
-- ---------------------------------------------------------------------------

-- 0052 — Engelleme gerçekten engellesin + pazaryeri bildirimleri
--
-- BULGU: `blocks` tablosu 0012'den beri var ama **hiçbir yerde
-- uygulanmıyor.** `dm_send` politikası yalnızca `sender_id = auth.uid()`
-- kontrol ediyor; engellediğin kişi sana mesaj atmaya devam edebiliyor.
-- Kullanıcı "engelledim" diyor, sistem engellemiyor — en kötü tür sessiz
-- hata, çünkü kullanıcı korunduğunu sanıyor.
--
-- Pazaryeri bunu zorunlu kıldı: yabancılarla mesajlaşılan bir yerde
-- engellemenin işlemesi şart.

-- ---------------------------------------------------------------------------
-- 1) Engelleme kontrolü
-- ---------------------------------------------------------------------------
create or replace function public.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.blocks
     where (blocker_id = p_a and blocked_id = p_b)
        or (blocker_id = p_b and blocked_id = p_a));
$$;

comment on function public.is_blocked_between(uuid, uuid) is
  'İki yön de kontrol ediliyor: A B''yi engellediyse B de A''ya yazamaz. '
  'Tek yönlü olsaydı engellenen kişi konuşmayı sürdürebilirdi.';

-- ---------------------------------------------------------------------------
-- 2) Engellenen kişiye mesaj gönderilemesin
--
-- Mevcut sohbet için davranış: **yeni mesaj engelleniyor.** Geçmiş mesajlar
-- duruyor — silmek, iki tarafın da kaydını yok etmek olurdu ve engelleme
-- bir silme aracı değil.
--
-- Karşı taraf engellendiğine dair bildirim ALMIYOR. Bildirim gitseydi
-- engelleme, taciz eden kişiye "beni engelledi" sinyali vererek başka
-- kanaldan devam etmesini kolaylaştırırdı.
-- ---------------------------------------------------------------------------
drop policy if exists "dm_send" on public.direct_messages;
create policy "dm_send" on public.direct_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not public.is_blocked_between(sender_id, recipient_id)
  );

-- ---------------------------------------------------------------------------
-- 3) Engellenen kişinin ilanları aramada görünmesin
--
-- `search_market_listings` yeniden yazılıyor; tek eklenen şart engelleme.
-- Fonksiyon `security definer` ve RLS'i atlıyor, o yüzden kontrol burada
-- olmak zorunda.
-- ---------------------------------------------------------------------------
create or replace function public.search_market_listings(
  p_query      text default null,
  p_sport      text default null,
  p_category   text default null,
  p_city       text default null,
  p_district   text default null,
  p_condition  text default null,
  p_delivery   text default null,
  p_seller     text default null,
  p_brand      text default null,
  p_min_price  numeric default null,
  p_max_price  numeric default null,
  p_sort       text default 'new',
  p_after_at   timestamptz default null,
  p_after_id   uuid default null,
  p_limit      int default 20)
returns table (
  id            uuid,
  title         text,
  price         numeric,
  item_condition text,
  seller_type   text,
  store_id      uuid,
  store_name    text,
  city_code     text,
  district      text,
  delivery      text,
  market_status text,
  image_path    text,
  created_at    timestamptz)
language sql
stable
security definer
set search_path = public
as $fn$
  select l.id, l.title, l.price, l.item_condition, l.seller_type,
         l.store_id, s.name,
         l.city_code, l.district, l.delivery, l.market_status,
         (select i.image_path from public.listing_images i
           where i.listing_id = l.id
           order by i.sort_order limit 1),
         l.created_at
    from public.listings l
    left join public.stores s on s.id = l.store_id
   where l.market_status in ('active', 'reserved', 'sold')
     -- Engellenen kişinin ilanı görünmüyor. `auth.uid()` null olabilir
     -- (giriş yapmamış kullanıcı); o durumda engelleme de yok.
     and (auth.uid() is null
          or not public.is_blocked_between(auth.uid(), l.owner_id))
     and (p_query     is null or public.tr_contains(l.title, p_query)
                              or public.tr_contains(coalesce(l.brand, ''), p_query))
     and (p_sport     is null or l.sport_code = p_sport)
     and (p_category  is null or l.category = p_category)
     and (p_city      is null or l.city_code = p_city)
     and (p_district  is null or l.district = p_district)
     and (p_condition is null or l.item_condition = p_condition)
     and (p_delivery  is null or l.delivery = p_delivery or l.delivery = 'both')
     and (p_seller    is null or l.seller_type = p_seller)
     and (p_brand     is null or public.tr_contains(coalesce(l.brand, ''), p_brand))
     and (p_min_price is null or l.price >= p_min_price)
     and (p_max_price is null or l.price <= p_max_price)
     and (p_after_at is null
          or (l.created_at, l.id) < (p_after_at, p_after_id))
   order by
     case when p_sort = 'price_asc'  then l.price end asc nulls last,
     case when p_sort = 'price_desc' then l.price end desc nulls last,
     l.created_at desc, l.id desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$fn$;

-- ---------------------------------------------------------------------------
-- 4) Mağaza başvurusu sonucu bildirilsin
--
-- Başvuran, kararı öğrenmek için ekranı tekrar tekrar açmak zorunda kalmasın.
-- Ret notu da gövdeye giriyor: sebebini bilmeyen aynı başvuruyu tekrar
-- gönderiyor.
-- ---------------------------------------------------------------------------
create or replace function public.notify_store_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  -- `pending`'e dönüş bir karar değil; bildirilmiyor.
  if new.status = 'pending' then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select m.profile_id,
         'store_decision',
         case new.status
           when 'approved'  then new.name || ' onaylandı'
           when 'rejected'  then new.name || ' başvurusu reddedildi'
           when 'suspended' then new.name || ' askıya alındı'
           else new.name || ' durumu değişti'
         end,
         coalesce(new.review_note, ''),
         'store',
         new.id
    from public.store_memberships m
   where m.store_id = new.id;

  return new;
end;
$fn$;

drop trigger if exists trg_notify_store_decision on public.stores;
create trigger trg_notify_store_decision
  after update on public.stores
  for each row execute function public.notify_store_decision();

-- ---------------------------------------------------------------------------
-- 5) Moderasyon kararı ilan sahibine bildirilsin
--
-- İlanı sessizce gizlemek en kötüsü: satıcı ilanının yayında olduğunu sanıp
-- bekliyor. Yalnızca moderasyon kaynaklı durumlar bildiriliyor; sahibin
-- kendi yaptığı "rezerve"/"satıldı" değişikliği zaten kendisinden geliyor.
-- ---------------------------------------------------------------------------
create or replace function public.notify_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.market_status is not distinct from old.market_status then
    return new;
  end if;
  if new.market_status not in ('under_review', 'hidden_by_moderation') then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  values (
    new.owner_id,
    'moderation',
    case new.market_status
      when 'under_review' then 'İlanın incelemeye alındı'
      else 'İlanın yayından kaldırıldı'
    end,
    new.title,
    'listing',
    new.id
  );

  return new;
end;
$fn$;

drop trigger if exists trg_notify_moderation on public.listings;
create trigger trg_notify_moderation
  after update on public.listings
  for each row execute function public.notify_moderation();

-- ---------------------------------------------------------------------------
-- 6) Yeni türlerin rotası
--
-- 0047'nin eşlemeleri korunuyor; iki yeni tür ekleniyor. Eşleme kaybını
-- `tools/check_push_routes.py` denetliyor.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    else '/bildirimler'
  end;
$fn$;

revoke execute on function public.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;


commit;

-- ===========================================================================
-- Bittiğinde doğrulama (ayrı çalıştır, işlem dışında):
--
--   select proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and proname in ('tr_fold','event_audience','athlete_card','event_roster',
--                      'create_market_listing','search_market_listings',
--                      'is_blocked_between')
--    order by 1;
--
-- Yedi satır dönmeli. Eksik varsa o migration uygulanmamış demektir.
-- ===========================================================================
