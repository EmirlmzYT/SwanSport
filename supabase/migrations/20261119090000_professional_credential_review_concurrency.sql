-- SwanSport Pro: pending kuyruğu için iyimser karar kapısı ekler. Mevcut
-- review_credential daha sonraki iptal/düzeltme işlerinde kullanılmaya devam
-- eder; Pro kuyruğu yalnız pending satırı sonuçlandırır.
set local lock_timeout = '15s';

drop function if exists public.review_credential(uuid,boolean,text,int,text,text,date);
create function public.review_credential(
  p_cred uuid,
  p_approve boolean,
  p_note text default null,
  p_coach_level int default null,
  p_sport_code text default null,
  p_national_id text default null,
  p_expires_on date default null)
returns void language plpgsql security definer set search_path=public as $$
declare c public.profile_credentials;v_national text;
begin
 if not public.is_platform_admin() then raise exception 'Yetkisiz' using errcode='42501';end if;
 if p_approve is null then raise exception 'İnceleme kararı gerekli';end if;
 select * into c from public.profile_credentials where id=p_cred for update;
 if not found then raise exception 'Başvuru bulunamadı';end if;
 if c.kind='identity' then
  if p_approve then
   v_national:=coalesce(nullif(trim(p_national_id),''),c.verified_national_id);
   if v_national is null or v_national !~ '^[1-9][0-9]{10}$' then raise exception 'İncelenmiş TCKN gerekli';end if;
   if c.verified_national_id is not null and c.verified_national_id<>v_national then raise exception 'Doğrulanmış TCKN değiştirilemez';end if;
   if not exists(select 1 from public.verification_documents d where d.owner_type='credential'
    and d.owner_id=c.id and d.uploaded_by=c.profile_id and d.doc_type='kimlik'
    and d.storage_path like c.profile_id::text||'/%') then raise exception 'Mevcut belge sisteminde kimlik belgesi gerekli';end if;
  else v_national:=c.verified_national_id;end if;
  update public.profile_credentials set verified_national_id=v_national,
   status=(case when p_approve then 'approved' else 'rejected' end)::public.verification_status,
   reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),note=p_note where id=c.id;
 else
  if p_national_id is not null then raise exception 'TCKN yalnız kimlik incelemesinde yazılır';end if;
  update public.profile_credentials set
   status=(case when p_approve then 'approved' else 'rejected' end)::public.verification_status,
   coach_level=coalesce(p_coach_level,coach_level),sport_code=coalesce(p_sport_code,sport_code),
   expires_on=coalesce(p_expires_on,expires_on),reviewed_by=auth.uid(),reviewed_at=clock_timestamp(),note=p_note where id=c.id;
 end if;
end $$;
revoke all on function public.review_credential(uuid,boolean,text,int,text,text,date) from public,anon,authenticated;
grant execute on function public.review_credential(uuid,boolean,text,int,text,text,date) to authenticated;

drop function if exists public.review_pending_credential(uuid,boolean,text,int,text,text,date);
create function public.review_pending_credential(
  p_cred uuid,
  p_approve boolean,
  p_note text default null,
  p_coach_level int default null,
  p_sport_code text default null,
  p_national_id text default null,
  p_expires_on date default null)
returns void language plpgsql security definer set search_path=public as $$
declare c public.profile_credentials;
begin
 if not public.is_platform_admin() then raise exception 'Yetkisiz' using errcode='42501';end if;
 if p_approve is null then raise exception 'İnceleme kararı gerekli';end if;
 if not p_approve and nullif(trim(p_note),'') is null then raise exception 'Ret gerekçesi gerekli';end if;
 select * into c from public.profile_credentials where id=p_cred for update;
 if not found then raise exception 'Başvuru bulunamadı';end if;
 if c.status<>'pending' then raise exception 'Başvuru zaten sonuçlandırıldı';end if;
 perform public.review_credential(
   p_cred,p_approve,p_note,p_coach_level,p_sport_code,p_national_id,p_expires_on);
end $$;
revoke all on function public.review_pending_credential(uuid,boolean,text,int,text,text,date) from public,anon,authenticated;
grant execute on function public.review_pending_credential(uuid,boolean,text,int,text,text,date) to authenticated;

create or replace function public.set_credential_sport(
  p_cred uuid,
  p_sport_code text)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_platform_admin() then raise exception 'Yetkisiz' using errcode='42501';end if;
 if nullif(trim(p_sport_code),'') is null then raise exception 'Branş gerekli';end if;
 update public.profile_credentials
 set sport_code=trim(p_sport_code)
 where id=p_cred and kind='coach' and status='approved';
 if not found then raise exception 'Onaylı antrenör belgesi bulunamadı';end if;
end $$;
revoke all on function public.set_credential_sport(uuid,text) from public,anon,authenticated;
grant execute on function public.set_credential_sport(uuid,text) to authenticated;
