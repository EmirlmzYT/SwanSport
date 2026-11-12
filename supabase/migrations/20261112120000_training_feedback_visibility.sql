-- Athlete-visible feedback is separate from the private staff event stream.
create table if not exists public.training_shared_feedback (
  session_id uuid not null references public.training_sessions(id) on delete cascade,
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  coach_id uuid references public.profiles(id) on delete set null,
  feedback text not null check (length(trim(feedback)) between 1 and 1000),
  shared_at timestamptz not null default now(),
  primary key (session_id, athlete_id)
);

alter table public.training_shared_feedback enable row level security;
drop policy if exists "training_shared_feedback_read" on public.training_shared_feedback;
create policy "training_shared_feedback_read"
on public.training_shared_feedback for select to authenticated
using (
  public.is_athlete_self(athlete_id)
  or public.can_manage_training_session(session_id)
);

create or replace function public.share_training_feedback(
  p_session uuid,
  p_athlete uuid,
  p_feedback text
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare s public.training_sessions%rowtype;
begin
  select * into s from public.training_sessions where id = p_session for update;
  if not found or s.kind <> 'club'
     or not coalesce(public.can_manage_training_session(p_session), false) then
    raise exception 'Bu oturumda geri bildirim paylaşma yetkin yok';
  end if;
  if s.status not in ('live', 'review', 'completed') then
    raise exception 'Oturum geri bildirime kapalı';
  end if;
  if p_feedback is null or length(trim(p_feedback)) not between 1 and 1000 then
    raise exception 'Geri bildirim 1-1000 karakter olmalı';
  end if;
  if not exists (
    select 1
      from public.training_session_participants p
      join public.athletes a on a.id = p.athlete_id
     where p.session_id = p_session
       and p.athlete_id = p_athlete
       and p.left_at is null
       and a.club_id = s.club_id
  ) then
    raise exception 'Sporcu bu oturumda değil';
  end if;

  insert into public.training_shared_feedback(
    session_id, athlete_id, coach_id, feedback, shared_at
  ) values (p_session, p_athlete, auth.uid(), trim(p_feedback), now())
  on conflict (session_id, athlete_id) do update
    set coach_id = excluded.coach_id,
        feedback = excluded.feedback,
        shared_at = excluded.shared_at;
end;
$fn$;

revoke all on table public.training_shared_feedback from public, anon;
grant select on table public.training_shared_feedback to authenticated;
revoke execute on function public.share_training_feedback(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.share_training_feedback(uuid, uuid, text)
  to authenticated;
