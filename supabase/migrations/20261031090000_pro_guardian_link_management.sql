set local lock_timeout = '15s';

-- Pro only consumes this masked projection. It intentionally omits guardian
-- phone/e-mail, athlete birth date, private notes and invite codes.
create or replace function public.club_guardian_link_overview(p_club uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare result jsonb;
begin
  if auth.uid() is null or not public.is_club_admin(p_club) then
    raise exception 'Kulüp yöneticisi yetkisi gerekli';
  end if;

  select jsonb_build_object(
    'athletes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'display_name', case
          when a.birth_date is null
            or a.birth_date > (current_date - interval '18 years')::date
          then left(a.first_name, 1) || '. ' || left(a.last_name, 1) || '.'
          else a.first_name || ' ' || a.last_name
        end,
        'is_minor', a.birth_date is null
          or a.birth_date > (current_date - interval '18 years')::date,
        'status', a.status,
        'guardian_count', (
          select count(*) from public.guardians g where g.athlete_id = a.id
        )
      ) order by a.first_name, a.last_name)
      from public.athletes a
      where a.club_id = p_club
    ), '[]'::jsonb),
    'links', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', g.id,
        'athlete_id', a.id,
        'athlete_display_name', case
          when a.birth_date is null
            or a.birth_date > (current_date - interval '18 years')::date
          then left(a.first_name, 1) || '. ' || left(a.last_name, 1) || '.'
          else a.first_name || ' ' || a.last_name
        end,
        'guardian_label', case
          when g.profile_id is null then 'Kayıtlı veli'
          else 'Doğrulanmış veli hesabı'
        end,
        'relationship', coalesce(nullif(trim(g.relationship), ''), 'Veli')
      ) order by a.first_name, a.last_name, g.created_at)
      from public.guardians g
      join public.athletes a on a.id = g.athlete_id
      where a.club_id = p_club
    ), '[]'::jsonb),
    'pending_invites', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id,
        'athlete_id', a.id,
        'athlete_display_name', case
          when a.birth_date is null
            or a.birth_date > (current_date - interval '18 years')::date
          then left(a.first_name, 1) || '. ' || left(a.last_name, 1) || '.'
          else a.first_name || ' ' || a.last_name
        end,
        'created_at', i.created_at,
        'expires_at', i.expires_at
      ) order by i.created_at desc)
      from public.invite_codes i
      join public.athletes a on a.id = i.athlete_id
      where a.club_id = p_club
        and i.purpose = 'guardian_link'
        and i.used_at is null
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$fn$;

create or replace function public.cancel_guardian_invite(p_invite uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare target_club uuid;
begin
  select a.club_id into target_club
  from public.invite_codes i
  join public.athletes a on a.id = i.athlete_id
  where i.id = p_invite
    and i.purpose = 'guardian_link'
    and i.used_at is null
  for update of i;

  if target_club is null or not public.is_club_admin(target_club) then
    raise exception 'Bekleyen veli davetini iptal etme yetkin yok';
  end if;

  delete from public.invite_codes
  where id = p_invite and used_at is null and purpose = 'guardian_link';
end;
$fn$;

revoke all on function public.club_guardian_link_overview(uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_guardian_invite(uuid)
  from public, anon, authenticated;
grant execute on function public.club_guardian_link_overview(uuid)
  to authenticated;
grant execute on function public.cancel_guardian_invite(uuid)
  to authenticated;
