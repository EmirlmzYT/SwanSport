-- 0125: Supabase güvenlik danışmanı sıkılaştırması.
-- Bilerek anonim olan salt-okuma uçları korunur; geri kalan SECURITY DEFINER
-- fonksiyonlar anonim çağrıya kapatılır. Tetikleyici fonksiyonları hiçbir API
-- rolü tarafından doğrudan çağrılamaz.

alter view public.athlete_public set (security_invoker = true);

do $$
declare
  fn record;
  anon_allowlist constant text[] := array[
    'accepted_match_officials',
    'court_sport_codes',
    'court_timeline',
    'discover_clubs',
    'get_public_platform_config',
    'join_launch_waitlist',
    'match_public_live_state',
    'match_public_roster',
    'match_public_standings_context',
    'my_feature_flags',
    'open_slots',
    'public_events',
    'public_federation_activities',
    'public_league_standings',
    'public_live_matches',
    'public_news_sources',
    'public_partner_requests',
    'public_program_fixture',
    'public_program_result',
    'public_sport_programs',
    'public_standings_leagues',
    'public_waitlist_summary',
    'search_faq',
    'search_market_listings',
    'tr_contains',
    'tr_fold',
    'turf_occupancy_grid'
  ];
begin
  for fn in
    select p.oid::regprocedure as signature,
           p.proname,
           p.prorettype = 'pg_catalog.trigger'::regtype as is_trigger
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.prosecdef
  loop
    execute format(
      'alter function %s set search_path = pg_catalog, public, auth',
      fn.signature
    );

    if fn.is_trigger then
      execute format(
        'revoke all on function %s from public, anon, authenticated',
        fn.signature
      );
    elsif not (fn.proname = any (anon_allowlist)) then
      execute format(
        'revoke execute on function %s from public, anon',
        fn.signature
      );
    end if;
  end loop;
end;
$$;
