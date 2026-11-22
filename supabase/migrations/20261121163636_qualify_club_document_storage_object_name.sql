drop policy if exists club_document_upload on storage.objects;
create policy club_document_upload on storage.objects for insert to authenticated
with check(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=storage.objects.name and public.is_club_staff(d.club_id)
  )
);

drop policy if exists club_document_read on storage.objects;
create policy club_document_read on storage.objects for select to authenticated
using(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=storage.objects.name
      and d.archived_at is null
      and public.is_club_staff(d.club_id)
  )
);

drop policy if exists club_document_update on storage.objects;
create policy club_document_update on storage.objects for update to authenticated
using(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=storage.objects.name and public.is_club_staff(d.club_id)
  )
)
with check(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=storage.objects.name and public.is_club_staff(d.club_id)
  )
);

drop policy if exists club_document_delete on storage.objects;
create policy club_document_delete on storage.objects for delete to authenticated
using(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=storage.objects.name and public.is_club_staff(d.club_id)
  )
);
