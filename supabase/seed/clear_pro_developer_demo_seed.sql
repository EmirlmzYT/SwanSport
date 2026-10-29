-- Remove mutable deterministic SwanSport Pro staging demo rows.
-- Existing staging account, roles, test club and test turf field are retained.
-- Immutable official federation history is intentionally retained.

do $cleanup$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_field constant uuid := '53570000-0000-4000-8000-000000000002';
begin
  if not exists (
    select 1 from auth.users u
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) then
    raise exception 'Pro developer demo cleanup guard failed';
  end if;

  perform set_config('request.jwt.claim.sub', v_profile::text, true);

  delete from public.platform_audit_logs where id::text like '53574444-83%';
  delete from public.launch_waitlist where source = 'pro-demo-seed';
  delete from public.notifications where id::text like '53574444-80%';
  delete from public.support_tickets where id::text like '53574444-81%';
  -- Official federation program, participants, fixtures, assignments and their
  -- audit rows are immutable by contract and intentionally remain in staging.
  delete from public.turf_occupancy where id::text like '53574444-70%';
  delete from public.facility_reservations where id::text like '53574444-69%';
  delete from public.bank_imports where id = '53574444-6801-4000-8000-000000000001';
  delete from public.finance_periods where id::text like '53574444-67%';
  delete from public.budgets where id::text like '53574444-66%';
  delete from public.expenses where id::text like '53574444-64%';
  delete from public.payments where id::text like '53574444-63%';
  delete from public.invoices where id::text like '53574444-62%';
  delete from public.cash_accounts where id::text like '53574444-61%';
  delete from public.athlete_fees where athlete_id::text like '53574444-10%';
  delete from public.fee_plans where id::text like '53574444-60%';
  delete from public.expense_categories where id::text like '53574444-65%';
  delete from public.documents where id::text like '53574444-50%';
  delete from public.announcements where id::text like '53574444-40%';
  delete from public.attendance where id::text like '53574444-31%';
  delete from public.events where id::text like '53574444-30%';
  delete from public.facilities where id::text like '53574444-20%';
  delete from public.athlete_sport_registrations where athlete_id::text like '53574444-10%';
  delete from public.athletes where id::text like '53574444-10%';
  delete from public.seasons where id = '53574444-0001-4000-8000-000000000001';
  delete from public.club_training_sports
   where club_id = v_club and sport_code = 'futbol' and created_by = v_profile;

  update public.clubs
     set status = 'pending', short_name = null, city = null, district = null,
         phone = null, email = null, bio = null, address = null,
         founded_year = null, brand_color = null, sections = null,
         updated_at = now()
   where id = v_club and name = '[TEST] SwanSport Rol Test Kulübü';

  update public.turf_fields
     set active = false, venue_name = '[TEST] Rol Test Sahası', phone = null,
         city_code = null, district = null, surface_type = null
   where id = v_field and name = '[TEST] Rol Test Sahası';
end
$cleanup$;
