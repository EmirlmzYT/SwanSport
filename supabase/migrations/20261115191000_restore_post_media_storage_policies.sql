-- Görselli gönderi metin gönderisinden önce Storage'a yazar. Eski
-- kurulumlarda post-media bucket/policy durumu şemadan ayrıştığında posts RLS
-- geçse bile Storage 42501 dönüyordu. Güncel sözleşmeyi idempotent kur.

set local lock_timeout = '15s';

insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do nothing;

update storage.buckets
   set public = true
 where id = 'post-media'
   and public is distinct from true;

drop policy if exists "postmedia_upload_own" on storage.objects;
drop policy if exists "postmedia_upload_own_v2" on storage.objects;
create policy "postmedia_upload_own_v2"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'post-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "postmedia_read_all" on storage.objects;
drop policy if exists "postmedia_read_all_v2" on storage.objects;
create policy "postmedia_read_all_v2"
on storage.objects for select to public
using (bucket_id = 'post-media');

drop policy if exists "postmedia_update_own" on storage.objects;
drop policy if exists "postmedia_update_own_v2" on storage.objects;
create policy "postmedia_update_own_v2"
on storage.objects for update to authenticated
using (
  bucket_id = 'post-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'post-media'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "postmedia_delete_own" on storage.objects;
drop policy if exists "postmedia_delete_own_v2" on storage.objects;
create policy "postmedia_delete_own_v2"
on storage.objects for delete to authenticated
using (
  bucket_id = 'post-media'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_platform_admin()
  )
);
