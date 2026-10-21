set local lock_timeout = '15s';

create or replace function public.create_swan_id_share(
  p_profile uuid default auth.uid(),
  p_hours int default 24
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_profile uuid := coalesce(p_profile, auth.uid());
  token text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if auth.uid() is null or target_profile is null or p_hours not between 1 and 168 then
    raise exception 'Geçersiz paylaşım';
  end if;
  if auth.uid() <> target_profile and not public._swan_profile_guardian(target_profile) then
    raise exception 'Paylaşım yetkin yok';
  end if;
  perform 1 from public.swan_id_cards where profile_id = target_profile;
  if not found then
    raise exception 'Swan ID bulunamadı';
  end if;
  insert into public.swan_id_share_tokens(profile_id, token_hash, expires_at, created_by)
  values (target_profile, encode(extensions.digest(token, 'sha256'), 'hex'),
          now() + make_interval(hours => p_hours), auth.uid());
  return token;
end
$$;

create or replace function public.revoke_my_swan_id_shares(
  p_profile uuid default auth.uid()
)
returns int
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_profile uuid := coalesce(p_profile, auth.uid());
  affected_count int;
begin
  if auth.uid() is null or target_profile is null then
    raise exception 'Oturum gerekli';
  end if;
  if auth.uid() <> target_profile and not public._swan_profile_guardian(target_profile) then
    raise exception 'Yetkin yok';
  end if;
  update public.swan_id_share_tokens
     set revoked_at = now()
   where profile_id = target_profile
     and revoked_at is null;
  get diagnostics affected_count = row_count;
  return affected_count;
end
$$;

revoke all on function public.create_swan_id_share(uuid, int) from public, anon;
revoke all on function public.revoke_my_swan_id_shares(uuid) from public, anon;
grant execute on function public.create_swan_id_share(uuid, int) to authenticated;
grant execute on function public.revoke_my_swan_id_shares(uuid) to authenticated;
