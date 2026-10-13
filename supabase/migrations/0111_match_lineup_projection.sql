set local lock_timeout = '15s';

-- Preserve per-participant 0110 scope: a club sees its own side only.
-- The referee projection additionally requires acceptance, not mere assignment.
drop function if exists public.match_approved_lineups(uuid);
create function public.match_approved_lineups(p_match_id uuid)
returns table (
  participant_id uuid,
  side text,
  starter_athlete_ids uuid[],
  substitute_athlete_ids uuid[],
  verified_by uuid,
  verified_at timestamptz,
  is_locked boolean,
  notes text
)
language plpgsql stable security definer
set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş gerekli' using errcode = '42501';
  end if;
  return query
  select a.participant_id,
    case when a.participant_id = m.home_id then 'home'::text else 'away'::text end,
    a.starter_athlete_ids, a.substitute_athlete_ids,
    a.verified_by, a.verified_at, a.is_locked, a.notes
  from public.match_lineup_approvals a
  join public.org_matches m on m.id = a.match_id
  join public.organizations o on o.id = m.org_id and o.official
  join public.org_participants p on p.id = a.participant_id
  where m.id = p_match_id and p.id in (m.home_id, m.away_id)
    and public._sports_approval_read(a.match_id, a.participant_id)
    and (
      (public.is_match_official(m.id) and exists (
        select 1 from public.match_officials mo
        where mo.match_id = m.id and mo.profile_id = auth.uid()
          and mo.status = 'accepted'))
      or public._sports_federation_scope(o.sport_code, o.city_code,
        array['referee_committee','disciplinary_board'])
      or (p.club_id is not null and public._sports_club_read(p.club_id))
    )
  order by case when a.participant_id = m.home_id then 0 else 1 end;
end $$;

revoke all on function public.match_approved_lineups(uuid) from public, anon, authenticated;
grant execute on function public.match_approved_lineups(uuid) to authenticated;
comment on function public.match_approved_lineups(uuid) is
  'Dar özel esame projeksiyonu; mevcut katılımcı RLS kapsamı + kabul edilmiş aktif branş hakemi. Genel kadro/ad/telefon/TC veya yeni tablo izni yok.';
