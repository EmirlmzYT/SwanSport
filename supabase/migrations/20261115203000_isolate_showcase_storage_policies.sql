-- 0132 vitrin Storage politikaları doğrudan public.showcase_videos okuduğu
-- için authenticated rolünde tablo ayrıcalığı hatası üretiyordu. PostgreSQL
-- AND sırasını garanti etmediğinden bu hata post-media gibi başka bucket
-- yüklemelerini de engelliyordu. Tabloyu Data API'ye açmadan kontrolü dar,
-- private security-definer fonksiyonlarına taşı.

set local lock_timeout = '15s';

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.showcase_storage_upload_allowed(
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.showcase_videos v
     where v.storage_path = p_name
       and v.owner_profile_id = (select auth.uid())
  )
$$;

create or replace function private.showcase_storage_read_allowed(
  p_name text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.showcase_videos v
     where v.storage_path = p_name
       and public._showcase_video_allowed(v)
  )
$$;

revoke all on function private.showcase_storage_upload_allowed(text)
  from public, anon, authenticated;
revoke all on function private.showcase_storage_read_allowed(text)
  from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.showcase_storage_upload_allowed(text)
  to authenticated;
grant execute on function private.showcase_storage_read_allowed(text)
  to authenticated;

drop policy if exists showcase_upload_own on storage.objects;
create policy showcase_upload_own
on storage.objects for insert to authenticated
with check (
  case
    when bucket_id = 'athlete-showcase' then
      (storage.foldername(name))[1] = (select auth.uid())::text
      and private.showcase_storage_upload_allowed(name)
    else false
  end
);

drop policy if exists showcase_read_allowed on storage.objects;
create policy showcase_read_allowed
on storage.objects for select to authenticated
using (
  case
    when bucket_id = 'athlete-showcase' then
      private.showcase_storage_read_allowed(name)
    else false
  end
);
