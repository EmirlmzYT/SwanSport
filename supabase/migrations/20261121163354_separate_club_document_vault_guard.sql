-- 0090 protects athlete vault rows with a user-owned `uid/belge_N.ext` path.
-- The later club archive deliberately uses a separate private bucket and a
-- `club_id/...` path. Keep the athlete rule intact while allowing only active
-- club staff to associate a club archive object with its own club.
create or replace function public.guard_vault_file_association()
returns trigger language plpgsql security definer set search_path=public as $fn$
begin
  if new.owner_type='athlete' and not exists(
    select 1 from public.athletes a
    where a.id=new.owner_id and a.club_id=new.club_id
  ) then
    raise exception 'Belge sahibi bu kulübün sporcusu değil.';
  end if;
  if tg_op='UPDATE' and new.storage_path is not distinct from old.storage_path
     and new.uploaded_by is not distinct from old.uploaded_by
     and new.owner_type is not distinct from old.owner_type
     and new.owner_id is not distinct from old.owner_id
     and new.club_id is not distinct from old.club_id then
    return new;
  end if;
  if new.storage_path is not null then
    if new.owner_type='athlete' then
      if auth.uid() is null or split_part(new.storage_path,'/',1)<>auth.uid()::text
         or new.storage_path !~ '^[0-9a-f-]+/belge_[0-9]+[.][a-z0-9]+$'
         or new.storage_path like '%/../%' then
        raise exception 'Belge dosyası kendi kasana ait olmalı.';
      end if;
    elsif new.owner_type is null or new.owner_type='club' then
      if auth.uid() is null or not public.is_club_staff(new.club_id)
         or split_part(new.storage_path,'/',1)<>new.club_id::text
         or new.storage_path like '%/../%' then
        raise exception 'Kulüp evrakı yalnız yetkili kulüp kasasına yüklenebilir.';
      end if;
    else
      raise exception 'Belge kasası türü desteklenmiyor.';
    end if;
    new.uploaded_by:=auth.uid();
  end if;
  return new;
end
$fn$;
revoke all on function public.guard_vault_file_association() from public,anon,authenticated;
