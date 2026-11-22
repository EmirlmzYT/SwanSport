set local lock_timeout = '15s';

alter table public.documents add column if not exists storage_path text;
alter table public.documents add column if not exists version int not null default 1;
alter table public.documents add column if not exists valid_until date;
alter table public.documents add column if not exists archived_at timestamptz;
alter table public.documents add column if not exists uploaded_by uuid references public.profiles(id) on delete set null;

alter table public.documents drop constraint if exists documents_version_positive;
alter table public.documents add constraint documents_version_positive check(version > 0);
alter table public.documents drop constraint if exists documents_storage_path_safe;
alter table public.documents add constraint documents_storage_path_safe check(
  storage_path is null or (
    length(storage_path) between 3 and 500
    and storage_path !~ '(^|/)\.\.(/|$)'
    and storage_path like club_id::text || '/%'
  )
);

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values(
  'club-documents','club-documents',false,10485760,
  array['application/pdf','image/jpeg','image/png']
)
on conflict(id) do update set
  public=false,
  file_size_limit=excluded.file_size_limit,
  allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists club_document_upload on storage.objects;
create policy club_document_upload on storage.objects for insert to authenticated
with check(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=name and public.is_club_staff(d.club_id)
  )
);

drop policy if exists club_document_read on storage.objects;
create policy club_document_read on storage.objects for select to authenticated
using(
  bucket_id='club-documents'
  and exists(
    select 1 from public.documents d
    where d.storage_path=name
      and d.archived_at is null
      and public.is_club_staff(d.club_id)
  )
);

drop policy if exists club_document_update on storage.objects;
create policy club_document_update on storage.objects for update to authenticated
using(
  bucket_id='club-documents'
  and exists(select 1 from public.documents d where d.storage_path=name and public.is_club_staff(d.club_id))
)
with check(
  bucket_id='club-documents'
  and exists(select 1 from public.documents d where d.storage_path=name and public.is_club_staff(d.club_id))
);

drop policy if exists club_document_delete on storage.objects;
create policy club_document_delete on storage.objects for delete to authenticated
using(
  bucket_id='club-documents'
  and exists(select 1 from public.documents d where d.storage_path=name and public.is_club_staff(d.club_id))
);

revoke all on table public.documents from anon;
