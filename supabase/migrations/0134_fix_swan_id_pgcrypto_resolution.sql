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

create or replace function public.verify_swan_id(p_token text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  target_profile uuid;
  result jsonb;
begin
  select profile_id
    into target_profile
    from public.swan_id_share_tokens
   where token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex')
     and revoked_at is null
     and expires_at > now();
  if target_profile is null then
    return jsonb_build_object('valid', false);
  end if;
  select jsonb_build_object(
           'valid', true,
           'public_code', card.public_code,
           'full_name', profile.full_name,
           'avatar_path', profile.avatar_path,
           'roles', coalesce((
             select jsonb_agg(jsonb_build_object(
               'kind', role.kind,
               'sport_code', role.sport_code,
               'coach_level', role.coach_level))
             from (
               select distinct credential.kind, credential.sport_code, credential.coach_level
                 from public.profile_credentials credential
                where credential.profile_id = target_profile
                  and credential.status = 'approved'
                  and credential.kind in ('coach', 'athlete_licensed', 'athlete_individual')
             ) role
           ), '[]'::jsonb)
         )
    into result
    from public.swan_id_cards card
    join public.profiles profile on profile.id = card.profile_id
   where card.profile_id = target_profile;
  return coalesce(result, jsonb_build_object('valid', false));
end
$$;

revoke all on function public.create_swan_id_share(uuid, int) from public, anon;
revoke all on function public.verify_swan_id(text) from public, authenticated;
grant execute on function public.create_swan_id_share(uuid, int) to authenticated;
grant execute on function public.verify_swan_id(text) to anon, authenticated;
