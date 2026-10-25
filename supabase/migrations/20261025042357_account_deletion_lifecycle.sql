set local lock_timeout = '15s';

-- Keep other people's sporting records; erase only the departing actor link.
-- The legacy delete_my_account() and its last-club-admin guard are unchanged.
alter table public.swan_id_share_tokens
  drop constraint if exists swan_id_share_tokens_created_by_fkey,
  add constraint swan_id_share_tokens_created_by_fkey foreign key(created_by)
    references public.profiles(id) on delete cascade;

alter table public.showcase_videos
  drop constraint if exists showcase_videos_guardian_approved_by_fkey,
  drop constraint if exists showcase_videos_club_verified_by_fkey,
  add constraint showcase_videos_guardian_approved_by_fkey foreign key(guardian_approved_by)
    references public.profiles(id) on delete set null,
  add constraint showcase_videos_club_verified_by_fkey foreign key(club_verified_by)
    references public.profiles(id) on delete set null;

alter table public.athlete_milestones
  alter column created_by drop not null,
  drop constraint if exists athlete_milestones_created_by_fkey,
  add constraint athlete_milestones_created_by_fkey foreign key(created_by)
    references public.profiles(id) on delete set null;

alter table public.event_preparations
  alter column updated_by drop not null,
  drop constraint if exists event_preparations_updated_by_fkey,
  add constraint event_preparations_updated_by_fkey foreign key(updated_by)
    references public.profiles(id) on delete set null;

alter table public.team_kudos
  alter column sender_profile_id drop not null,
  drop constraint if exists team_kudos_sender_profile_id_fkey,
  add constraint team_kudos_sender_profile_id_fkey foreign key(sender_profile_id)
    references public.profiles(id) on delete set null;

-- No client privileges or RLS policies are widened. All writes still use the
-- existing RPCs, which take their actor from auth.uid(), never from a nullable FK.
