set local lock_timeout = '15s';

-- Provider attestation is a backend responsibility. No user/admin EXECUTE here.
-- The existing 0100 unique indexes remain the final concurrent-write authority.
create table if not exists public._identity_completion_context (
  transaction_id bigint not null,
  credential_id uuid not null,
  profile_id uuid not null,
  primary key(transaction_id, credential_id)
);
create table if not exists public.identity_verification_audit (
  id bigint generated always as identity primary key,
  profile_id uuid references public.profiles(id) on delete set null,
  credential_id uuid not null,
  action text not null check(action = 'backend_identity_verified'),
  created_at timestamptz not null default clock_timestamp()
);
create table if not exists public._identity_attempt_windows (
  key text primary key check(key ~ '^[ui]:[a-f0-9]{64}$'),
  attempts timestamptz[] not null
);
alter table public._identity_completion_context enable row level security;
alter table public.identity_verification_audit enable row level security;
alter table public._identity_attempt_windows enable row level security;
revoke all on public._identity_completion_context, public.identity_verification_audit,
  public._identity_attempt_windows from public, anon, authenticated, service_role;
revoke all on sequence public.identity_verification_audit_id_seq from public, anon, authenticated, service_role;

create or replace function public._identity_completion_allowed(p_id uuid, p_profile uuid)
returns boolean language sql security definer set search_path=public as $$
  select exists(select 1 from public._identity_completion_context c
    where c.transaction_id=txid_current() and c.credential_id=p_id and c.profile_id=p_profile)
$$;
revoke all on function public._identity_completion_allowed(uuid,uuid) from public, anon, authenticated, service_role;

-- Surgical extension: all other C1 checks and the manual reviewer remain intact.
do $$
declare body text; old text := 'and (current_user in (''anon'',''authenticated'') or not public.is_platform_admin()) then';
begin
  body := pg_get_functiondef('public._c1_credential_guard()'::regprocedure);
  if position('public._identity_completion_allowed' in body)=0 then
    if position(old in body)=0 then raise exception 'Unexpected C1 credential guard; refusing to weaken it'; end if;
    body := replace(body,old,
      'and (current_user in (''anon'',''authenticated'') or (not public.is_platform_admin() and not (new.kind=''identity'' and new.status=''approved'' and new.reviewed_by is null and public._identity_completion_allowed(new.id,new.profile_id)))) then');
    execute body;
  end if;
end $$;

-- Removing the obsolete unsafe signature prevents PostgREST overload/bypass.
drop function if exists public.complete_identity_verification(text,int);
create or replace function public.complete_identity_verification(
  p_profile_id uuid, p_national_id text, p_birth_year int)
returns void language plpgsql security definer set search_path=public as $$
declare cred public.profile_credentials; digits int[]; odd_sum int; even_sum int;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'Backend identity verification only' using errcode='42501';
  end if;
  if p_profile_id is null or p_national_id is null or p_national_id !~ '^[1-9][0-9]{10}$'
    or p_birth_year is null or p_birth_year<1900
    or p_birth_year>extract(year from (now() at time zone 'Europe/Istanbul'))::int then
    raise exception 'Geçersiz kimlik bilgileri' using errcode='22023';
  end if;
  select array_agg(substr(p_national_id,n,1)::int order by n) into digits from generate_series(1,11) n;
  odd_sum:=digits[1]+digits[3]+digits[5]+digits[7]+digits[9];
  even_sum:=digits[2]+digits[4]+digits[6]+digits[8];
  if ((odd_sum*7-even_sum)%10+10)%10<>digits[10]
    or (odd_sum+even_sum+digits[10])%10<>digits[11] then
    raise exception 'Geçersiz kimlik bilgileri' using errcode='22023';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_profile_id::text,115));
  perform 1 from public.profiles where id=p_profile_id for key share;
  if not found then raise exception 'Hesap bulunamadı' using errcode='22023'; end if;
  -- Do not manufacture a full date or change any profiles/athletes birth date.
  insert into public.profile_credentials(profile_id,kind) values(p_profile_id,'identity')
    on conflict(profile_id) where kind='identity' do nothing;
  select * into cred from public.profile_credentials
    where profile_id=p_profile_id and kind='identity' for update;
  if cred.verified_national_id is not null and cred.verified_national_id<>p_national_id then
    raise exception 'Doğrulanmış TCKN değiştirilemez' using errcode='22023';
  end if;
  if exists(select 1 from public.profile_credentials
    where verified_national_id=p_national_id and profile_id<>p_profile_id) then
    raise exception 'Bu T.C. Kimlik Numarası başka bir hesapta onaylı' using errcode='23505';
  end if;
  if cred.status='approved' then return; end if;
  insert into public._identity_completion_context values(txid_current(),cred.id,p_profile_id);
  update public.profile_credentials set status='approved', verified_national_id=p_national_id,
    reviewed_at=clock_timestamp(),reviewed_by=null,note=null where id=cred.id;
  insert into public.identity_verification_audit(profile_id,credential_id,action)
    values(p_profile_id,cred.id,'backend_identity_verified');
  delete from public._identity_completion_context where transaction_id=txid_current() and credential_id=cred.id;
end $$;
revoke all on function public.complete_identity_verification(uuid,text,int) from public, anon, authenticated, service_role;
grant execute on function public.complete_identity_verification(uuid,text,int) to service_role;

-- Exact rolling 60s limit across Workers/isolates. Keys are server-side HMACs;
-- no raw IP, TCKN, submitted names, token or birth year is stored here.
create or replace function public.consume_identity_verification_attempt(p_user_key text,p_ip_key text)
returns boolean language plpgsql security definer set search_path=public as $$
declare k text; recent timestamptz[]; stamp timestamptz; blocked boolean:=false;
begin
  if auth.role() is distinct from 'service_role' then raise exception 'Backend only' using errcode='42501';end if;
  if p_user_key is null or p_user_key !~ '^u:[a-f0-9]{64}$'
    or p_ip_key is null or p_ip_key !~ '^i:[a-f0-9]{64}$' then
    raise exception 'Invalid rate keys' using errcode='22023';end if;
  for k in select v from unnest(array[p_user_key,p_ip_key]) v order by v loop
    perform pg_advisory_xact_lock(hashtextextended(k,115));
  end loop;
  stamp:=clock_timestamp();
  foreach k in array array[p_user_key,p_ip_key] loop
    select array(select a from unnest(w.attempts) a where a>stamp-interval '60 seconds') into recent
      from public._identity_attempt_windows w where w.key=k;
    if coalesce(cardinality(recent),0)>=5 then blocked:=true;end if;
  end loop;
  if blocked then return false;end if;
  foreach k in array array[p_user_key,p_ip_key] loop
    insert into public._identity_attempt_windows(key,attempts) values(k,array[stamp])
    on conflict(key) do update set attempts=array(select a from unnest(_identity_attempt_windows.attempts) a
      where a>stamp-interval '60 seconds')||array[stamp];
  end loop;
  -- Bounded opportunistic retention cleanup; inactive keys have no identity data.
  delete from public._identity_attempt_windows where key in
    (select w.key from public._identity_attempt_windows w
      where w.attempts[cardinality(w.attempts)]<stamp-interval '1 day'
      limit 100 for update skip locked);
  return true;
end $$;
revoke all on function public.consume_identity_verification_attempt(text,text) from public,anon,authenticated,service_role;
grant execute on function public.consume_identity_verification_attempt(text,text) to service_role;

-- Do not return verified TCKN even in a client's credential SELECT *.
-- Existing service projections already enumerate their safe fields.
revoke select on public.profile_credentials from public,anon,authenticated;
revoke select (verified_national_id) on public.profile_credentials from public,anon,authenticated;
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name),',' order by ordinal_position) into cols
    from information_schema.columns where table_schema='public' and table_name='profile_credentials'
      and column_name<>'verified_national_id';
  execute format('grant select (%s) on public.profile_credentials to authenticated',cols);
end $$;

insert into public.faq_entries(question,answer,category,feature,route,sort_order,active)
select 'T.C. kimliğimi otomatik doğrulayabilir miyim?',
  'Otomatik doğrulama yalnız yetkili kurumsal servis yapılandırıldığında çalışır. Servis kapalıysa Kimlik sekmesinden belgenizi yükleyip platform incelemesine gönderebilirsiniz. Numara kontrolü tek başına kimlik onayı değildir; kimlik onayı spor lisansı veya yaş doğrulaması yerine geçmez.',
  'verification',null,'/dogrulama',115,true
where not exists(select 1 from public.faq_entries where question='T.C. kimliğimi otomatik doğrulayabilir miyim?');
