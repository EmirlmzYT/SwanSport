-- SwanSport Pro staging developer demo data.
--
-- Operator-only seed. Never include this file in migrations or production
-- automation. It is guarded by the staging-only role test club and the
-- server-controlled Pro workspace preview flag of the designated account.
-- All created rows use deterministic UUIDs and [DEMO] labels.

do $seed$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_field constant uuid := '53570000-0000-4000-8000-000000000002';
  v_federation constant uuid := 'eabd2663-0042-4d4a-9a96-245b69d4dd37';
  v_month_start date := date_trunc('month', current_date)::date;
begin
  if not exists (
    select 1
      from auth.users u
      join public.profiles p on p.id = u.id
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
       and p.is_platform_admin
  ) then
    raise exception 'Pro developer demo account guard failed';
  end if;

  if not exists (
    select 1 from public.clubs
     where id = v_club and name = '[TEST] SwanSport Rol Test Kulübü'
  ) or not exists (
    select 1 from public.turf_fields
     where id = v_field and name = '[TEST] Rol Test Sahası'
  ) or not exists (
    select 1 from public.federation_roles
     where profile_id = v_profile
       and federation_id = v_federation
       and role = 'president'
       and revoked_at is null
  ) then
    raise exception 'Staging-only Pro role fixture guard failed';
  end if;

  update public.clubs
     set status = 'active',
         short_name = 'Swan Demo',
         city = 'İstanbul',
         district = 'Kadıköy',
         phone = '0212 000 00 00',
         email = 'demo-kulup@swansport.test',
         bio = '[DEMO] Profesyonel operasyon ekranları için staging kulübü.',
         address = '[DEMO] Kadıköy Spor Yerleşkesi',
         founded_year = 2024,
         sport_code = 'futbol',
         brand_color = '#0F766E',
         sections = array['about', 'roster', 'announcements', 'contact'],
         updated_at = now()
   where id = v_club;

  update public.turf_fields
     set active = true,
         venue_name = '[DEMO] SwanSport Spor Tesisi',
         phone = '0212 000 00 01',
         city_code = '34',
         district = 'Kadıköy',
         sport_code = 'futbol',
         opens_at = time '08:00',
         closes_at = time '23:30',
         surface_type = 'Yeni nesil sentetik çim'
   where id = v_field;

  insert into public.seasons (id, club_id, label, starts_on, ends_on, is_active)
  values (
    '53574444-0001-4000-8000-000000000001', v_club,
    '[DEMO] 2026-2027 Sezonu', current_date - 90, current_date + 275, true
  ) on conflict (id) do nothing;

  insert into public.club_training_sports (club_id, sport_code, created_by)
  values (v_club, 'futbol', v_profile)
  on conflict (club_id, sport_code) do nothing;

end
$seed$;

do $seed_athletes$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
begin
  if not exists (
    select 1 from auth.users u where u.id = v_profile
      and lower(u.email) = 'emirbendeniz@gmail.com'
      and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) or not exists (
    select 1 from public.clubs where id = v_club
      and name = '[TEST] SwanSport Rol Test Kulübü'
  ) then
    raise exception 'Pro developer athlete demo guard failed';
  end if;

  insert into public.athletes (
    id, club_id, first_name, last_name, birth_date, position,
    license_number, status, jersey_number,
    height_cm, weight_kg, dominant_side, branch, started_at
  ) values
    ('53574444-1001-4000-8000-000000000001', v_club, 'Deniz', 'Yılmaz', '2001-03-12', 'Kaleci', 'DEMO-FUT-001', 'active', 1, 188, 82, 'right', 'futbol', current_date - 900),
    ('53574444-1002-4000-8000-000000000002', v_club, 'Efe', 'Kaya', '2002-07-21', 'Stoper', 'DEMO-FUT-002', 'active', 4, 185, 79, 'right', 'futbol', current_date - 700),
    ('53574444-1003-4000-8000-000000000003', v_club, 'Mert', 'Demir', '2000-11-05', 'Orta saha', 'DEMO-FUT-003', 'active', 8, 179, 73, 'right', 'futbol', current_date - 1100),
    ('53574444-1004-4000-8000-000000000004', v_club, 'Arda', 'Çelik', '2003-01-18', 'Forvet', 'DEMO-FUT-004', 'injured', 9, 181, 75, 'left', 'futbol', current_date - 500),
    ('53574444-1005-4000-8000-000000000005', v_club, 'Can', 'Aydın', '2001-09-30', 'Kanat', 'DEMO-FUT-005', 'pending_license', 11, 176, 69, 'both', 'futbol', current_date - 300)
  on conflict (id) do nothing;

  insert into public.athlete_sport_registrations (
    athlete_id, sport_code, club_id, license_number, expires_on
  ) values
    ('53574444-1001-4000-8000-000000000001', 'futbol', v_club, 'DEMO-REG-001', current_date + 365),
    ('53574444-1002-4000-8000-000000000002', 'futbol', v_club, 'DEMO-REG-002', current_date + 365),
    ('53574444-1003-4000-8000-000000000003', 'futbol', v_club, 'DEMO-REG-003', current_date + 365),
    ('53574444-1004-4000-8000-000000000004', 'futbol', v_club, 'DEMO-REG-004', current_date + 365),
    ('53574444-1005-4000-8000-000000000005', 'futbol', v_club, 'DEMO-REG-005', current_date + 30)
  on conflict (athlete_id, sport_code) do nothing;

end
$seed_athletes$;

do $seed_club_ops$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
begin
  if not exists (
    select 1 from auth.users u
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) or not exists (
    select 1 from public.clubs
     where id = v_club and name = '[TEST] SwanSport Rol Test Kulübü'
  ) then
    raise exception 'Pro developer club operations demo guard failed';
  end if;

  insert into public.facilities (id, club_id, name, kind, occupancy, status)
  values
    ('53574444-2001-4000-8000-000000000001', v_club, '[DEMO] Ana Saha', 'Futbol Sahası', 68, 'Kullanımda'),
    ('53574444-2002-4000-8000-000000000002', v_club, '[DEMO] Kondisyon Salonu', 'Fitness', 24, 'Müsait')
  on conflict (id) do nothing;

  insert into public.events (
    id, club_id, title, place, kind, starts_at, ends_at, opponent,
    home_score, away_score, result_note, facility_id, is_public,
    capacity, description, status
  ) values
    ('53574444-3001-4000-8000-000000000001', v_club, '[DEMO] Taktik Antrenman', '[DEMO] Ana Saha', 'training', now() + interval '1 day 2 hours', now() + interval '1 day 3 hours 30 minutes', null, null, null, null, '53574444-2001-4000-8000-000000000001', false, 24, 'Geçiş oyunu ve duran top çalışması.', 'scheduled'),
    ('53574444-3002-4000-8000-000000000002', v_club, '[DEMO] Lig Maçı', 'SwanSport Stadı', 'match', now() + interval '4 days', now() + interval '4 days 2 hours', 'Boğaziçi Spor', null, null, null, '53574444-2001-4000-8000-000000000001', true, 500, 'Staging maç operasyonu örneği.', 'scheduled'),
    ('53574444-3003-4000-8000-000000000003', v_club, '[DEMO] Geçen Hafta Maçı', 'Deplasman', 'match', now() - interval '7 days', now() - interval '7 days' + interval '2 hours', 'Anadolu Yıldızları', 3, 1, 'İkinci yarıda iki gol.', null, true, null, 'Tamamlanmış maç örneği.', 'completed'),
    ('53574444-3004-4000-8000-000000000004', v_club, '[DEMO] Yönetim Toplantısı', 'Toplantı Odası', 'meeting', now() + interval '2 days', now() + interval '2 days 1 hour', null, null, null, null, null, false, 15, 'Aylık operasyon değerlendirmesi.', 'scheduled')
  on conflict (id) do nothing;

end
$seed_club_ops$;

do $seed_club_history$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
begin
  if not exists (
    select 1 from auth.users u where u.id = v_profile
      and lower(u.email) = 'emirbendeniz@gmail.com'
      and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) then
    raise exception 'Pro developer club history demo guard failed';
  end if;

  insert into public.attendance (id, club_id, event_id, athlete_id, status, actor_id, marked_at)
  values
    ('53574444-3101-4000-8000-000000000001', v_club, '53574444-3003-4000-8000-000000000003', '53574444-1001-4000-8000-000000000001', 'present', v_profile, now() - interval '7 days'),
    ('53574444-3102-4000-8000-000000000002', v_club, '53574444-3003-4000-8000-000000000003', '53574444-1002-4000-8000-000000000002', 'present', v_profile, now() - interval '7 days'),
    ('53574444-3103-4000-8000-000000000003', v_club, '53574444-3003-4000-8000-000000000003', '53574444-1003-4000-8000-000000000003', 'late', v_profile, now() - interval '7 days'),
    ('53574444-3104-4000-8000-000000000004', v_club, '53574444-3003-4000-8000-000000000003', '53574444-1004-4000-8000-000000000004', 'excused', v_profile, now() - interval '7 days'),
    ('53574444-3105-4000-8000-000000000005', v_club, '53574444-3003-4000-8000-000000000003', '53574444-1005-4000-8000-000000000005', 'absent', v_profile, now() - interval '7 days')
  on conflict (id) do nothing;

  insert into public.announcements (id, club_id, author_id, title, body, pinned)
  values
    ('53574444-4001-4000-8000-000000000001', v_club, v_profile, '[DEMO] Hafta programı', 'Antrenman ve maç saatleri takvimde güncellendi.', true),
    ('53574444-4002-4000-8000-000000000002', v_club, v_profile, '[DEMO] Lisans hatırlatması', 'Süresi yaklaşan lisanslar için belge kontrolü yapılacaktır.', false),
    ('53574444-4003-4000-8000-000000000003', v_club, v_profile, '[DEMO] Tesis bakımı', 'Kondisyon salonu cuma sabahı bakımdadır.', false)
  on conflict (id) do nothing;

  insert into public.documents (
    id, club_id, name, kind, size_label, owner_type, doc_type,
    owner_id, issued_on, expires_on, verified, note
  ) values
    ('53574444-5001-4000-8000-000000000001', v_club, '[DEMO] Kulüp faaliyet belgesi', 'file', '320 KB', 'club', 'activity_certificate', null, current_date - 90, current_date + 275, true, 'Dosya içeriği yüklenmemiş demo kaydıdır.'),
    ('53574444-5002-4000-8000-000000000002', v_club, '[DEMO] Tesis sigorta poliçesi', 'file', '480 KB', 'club', 'insurance', null, current_date - 180, current_date + 45, true, 'Yaklaşan süre örneği.'),
    ('53574444-5003-4000-8000-000000000003', v_club, '[DEMO] Eksik sağlık belgesi', 'file', null, 'athlete', 'health_report', '53574444-1005-4000-8000-000000000005', null, null, false, 'Belge bekleniyor örneği.')
  on conflict (id) do nothing;

end
$seed_club_history$;

do $seed_finance$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_month_start date := date_trunc('month', current_date)::date;
begin
  if not exists (
    select 1 from auth.users u
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) or not exists (
    select 1 from public.clubs
     where id = v_club and name = '[TEST] SwanSport Rol Test Kulübü'
  ) then
    raise exception 'Pro developer finance demo guard failed';
  end if;

  insert into public.fee_plans (id, club_id, name, amount, period_kind, due_day, active)
  values
    ('53574444-6001-4000-8000-000000000001', v_club, '[DEMO] Aylık Sporcu Aidatı', 1750, 'monthly', 10, true),
    ('53574444-6002-4000-8000-000000000002', v_club, '[DEMO] Performans Paketi', 2400, 'monthly', 15, true)
  on conflict (id) do nothing;

  insert into public.athlete_fees (athlete_id, club_id, plan_id, custom_amount, note, active)
  values
    ('53574444-1001-4000-8000-000000000001', v_club, '53574444-6001-4000-8000-000000000001', null, '[DEMO] Standart plan', true),
    ('53574444-1002-4000-8000-000000000002', v_club, '53574444-6001-4000-8000-000000000001', 1500, '[DEMO] İndirimli plan', true),
    ('53574444-1003-4000-8000-000000000003', v_club, '53574444-6002-4000-8000-000000000002', null, '[DEMO] Performans planı', true)
  on conflict (athlete_id) do nothing;

  insert into public.cash_accounts (id, club_id, name, kind, active)
  values
    ('53574444-6101-4000-8000-000000000001', v_club, '[DEMO] Ana Banka Hesabı', 'bank', true),
    ('53574444-6102-4000-8000-000000000002', v_club, '[DEMO] Kulüp Kasası', 'cash', true),
    ('53574444-6103-4000-8000-000000000003', v_club, '[DEMO] POS Hesabı', 'pos', true)
  on conflict (id) do nothing;

  insert into public.invoices (
    id, club_id, athlete_id, label, amount, status, period,
    plan_id, due_date, kind, note
  ) values
    ('53574444-6201-4000-8000-000000000001', v_club, '53574444-1001-4000-8000-000000000001', '[DEMO] Ekim aidatı', 1750, 'paid', to_char(current_date, 'YYYY-MM'), '53574444-6001-4000-8000-000000000001', current_date - 12, 'aidat', 'Ödenmiş fatura örneği.'),
    ('53574444-6202-4000-8000-000000000002', v_club, '53574444-1002-4000-8000-000000000002', '[DEMO] Ekim aidatı', 1500, 'pending', to_char(current_date, 'YYYY-MM'), '53574444-6001-4000-8000-000000000001', current_date + 5, 'aidat', 'Bekleyen fatura örneği.'),
    ('53574444-6203-4000-8000-000000000003', v_club, '53574444-1003-4000-8000-000000000003', '[DEMO] Performans paketi', 2400, 'overdue', to_char(current_date - interval '1 month', 'YYYY-MM'), '53574444-6002-4000-8000-000000000002', current_date - 18, 'aidat', 'Gecikmiş fatura örneği.'),
    ('53574444-6204-4000-8000-000000000004', v_club, '53574444-1004-4000-8000-000000000004', '[DEMO] Malzeme katkı payı', 850, 'pending', to_char(current_date, 'YYYY-MM'), null, current_date + 12, 'ekstra', 'Ek ücret örneği.')
  on conflict (id) do nothing;

  insert into public.payments (
    id, club_id, invoice_id, athlete_id, amount, method, status,
    paid_at, note, confirmed_by, confirmed_at, account_id
  ) values
    ('53574444-6301-4000-8000-000000000001', v_club, '53574444-6201-4000-8000-000000000001', '53574444-1001-4000-8000-000000000001', 1750, 'havale', 'confirmed', current_date - 10, '[DEMO] Banka havalesi', v_profile, now() - interval '10 days', '53574444-6101-4000-8000-000000000001'),
    ('53574444-6302-4000-8000-000000000002', v_club, '53574444-6202-4000-8000-000000000002', '53574444-1002-4000-8000-000000000002', 750, 'nakit', 'pending', current_date, '[DEMO] Kısmi ödeme beyanı', null, null, '53574444-6102-4000-8000-000000000002')
  on conflict (id) do nothing;

end
$seed_finance$;

do $seed_finance_ops$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_month_start date := date_trunc('month', current_date)::date;
begin
  if not exists (
    select 1 from auth.users u
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) or not exists (
    select 1 from public.clubs
     where id = v_club and name = '[TEST] SwanSport Rol Test Kulübü'
  ) then
    raise exception 'Pro developer finance operations demo guard failed';
  end if;

  insert into public.expense_categories (id, club_id, name, sort)
  values
    ('53574444-6501-4000-8000-000000000001', v_club, '[DEMO] Tesis ve bakım', 10),
    ('53574444-6502-4000-8000-000000000002', v_club, '[DEMO] Spor ekipmanı', 20),
    ('53574444-6503-4000-8000-000000000003', v_club, '[DEMO] Seyahat', 30)
  on conflict (id) do nothing;

  insert into public.expenses (
    id, club_id, category_id, account_id, supplier, amount, spent_on,
    note, status, entered_by, facility_id, event_id, approval_status,
    submitted_at
  ) values
    ('53574444-6401-4000-8000-000000000001', v_club, '53574444-6501-4000-8000-000000000001', '53574444-6101-4000-8000-000000000001', '[DEMO] Saha Bakım Ltd.', 12800, current_date - 14, 'Aylık saha bakımı', 'complete', v_profile, '53574444-2001-4000-8000-000000000001', null, 'approved', now() - interval '15 days'),
    ('53574444-6402-4000-8000-000000000002', v_club, '53574444-6502-4000-8000-000000000002', '53574444-6102-4000-8000-000000000002', '[DEMO] Spor Market', 4750, current_date - 5, 'Antrenman malzemeleri', 'complete', v_profile, null, null, 'not_required', null),
    ('53574444-6403-4000-8000-000000000003', v_club, '53574444-6503-4000-8000-000000000003', '53574444-6101-4000-8000-000000000001', '[DEMO] Ulaşım AŞ', 9200, current_date + 4, 'Deplasman otobüsü', 'draft', v_profile, null, '53574444-3002-4000-8000-000000000002', 'pending', now()),
    ('53574444-6404-4000-8000-000000000004', v_club, '53574444-6502-4000-8000-000000000002', null, '[DEMO] Forma Tedarikçisi', 18500, current_date, 'Yeni sezon forma teklifi', 'draft', v_profile, null, null, 'rejected', now() - interval '2 days')
  on conflict (id) do nothing;

  insert into public.budgets (
    id, club_id, period_from, period_to, scope, planned, note,
    owner_id, status, created_by
  ) values
    ('53574444-6601-4000-8000-000000000001', v_club, v_month_start, (v_month_start + interval '1 month - 1 day')::date, 'club', 75000, '[DEMO] Aylık kulüp operasyon bütçesi', v_profile, 'approved', v_profile),
    ('53574444-6602-4000-8000-000000000002', v_club, v_month_start, (v_month_start + interval '3 months - 1 day')::date, 'club', 210000, '[DEMO] Üç aylık tahmin', v_profile, 'draft', v_profile)
  on conflict (id) do nothing;

  insert into public.finance_periods (
    id, club_id, period_from, period_to, status, close_note, created_by
  ) values
    ('53574444-6701-4000-8000-000000000001', v_club, v_month_start, (v_month_start + interval '1 month - 1 day')::date, 'open', '[DEMO] Açık dönem', v_profile),
    ('53574444-6702-4000-8000-000000000002', v_club, (v_month_start + interval '1 month')::date, (v_month_start + interval '2 months - 1 day')::date, 'preparing', '[DEMO] Hazırlık dönemi', v_profile)
  on conflict (id) do nothing;

end
$seed_finance_ops$;

do $seed_reconciliation$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
begin
  if not exists (
    select 1 from auth.users u where u.id = v_profile
      and lower(u.email) = 'emirbendeniz@gmail.com'
      and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) then
    raise exception 'Pro developer reconciliation demo guard failed';
  end if;

  insert into public.bank_imports (
    id, club_id, account_id, file_hash, row_count,
    period_from, period_to, imported_by
  ) values (
    '53574444-6801-4000-8000-000000000001', v_club,
    '53574444-6101-4000-8000-000000000001',
    'demo-swansport-pro-bank-import-v1', 3, current_date - 30,
    current_date, v_profile
  ) on conflict (id) do nothing;

  insert into public.bank_transactions (
    id, import_id, club_id, account_id, row_no, txn_on, amount,
    direction, raw_description, match_status, matched_kind, matched_id,
    decided_by, decided_at
  ) values
    ('53574444-6811-4000-8000-000000000001', '53574444-6801-4000-8000-000000000001', v_club, '53574444-6101-4000-8000-000000000001', 1, current_date - 10, 1750, 'in', '[DEMO] Aidat havalesi', 'matched', 'payment', '53574444-6301-4000-8000-000000000001', v_profile, now() - interval '9 days'),
    ('53574444-6812-4000-8000-000000000002', '53574444-6801-4000-8000-000000000001', v_club, '53574444-6101-4000-8000-000000000001', 2, current_date - 4, 4750, 'out', '[DEMO] Spor ekipmanı ödemesi', 'unmatched', null, null, null, null),
    ('53574444-6813-4000-8000-000000000003', '53574444-6801-4000-8000-000000000001', v_club, '53574444-6101-4000-8000-000000000001', 3, current_date - 2, 2500, 'in', '[DEMO] Açıklamasız banka girişi', 'unmatched', null, null, null, null)
  on conflict (id) do nothing;

  insert into public.facility_reservations (
    id, club_id, facility_id, title, kind, starts_at, ends_at,
    reserved_by_name, status, fee, notes, created_by
  ) values
    ('53574444-6901-4000-8000-000000000001', v_club, '53574444-2001-4000-8000-000000000001', '[DEMO] Altyapı antrenmanı', 'club_event', now() + interval '1 day 2 hours', now() + interval '1 day 3 hours 30 minutes', 'SwanSport U19', 'confirmed', 0, 'Etkinlikle çakışma örneği.', v_profile),
    ('53574444-6902-4000-8000-000000000002', v_club, '53574444-2002-4000-8000-000000000002', '[DEMO] Bireysel performans dersi', 'private_lesson', now() + interval '2 days 4 hours', now() + interval '2 days 5 hours', 'Demo Sporcu', 'pending', 1200, 'Onay bekleyen rezervasyon.', v_profile),
    ('53574444-6903-4000-8000-000000000003', v_club, '53574444-2001-4000-8000-000000000001', '[DEMO] Zemin bakımı', 'maintenance', now() + interval '6 days', now() + interval '6 days 3 hours', 'Teknik Ekip', 'confirmed', 0, 'Bakım blokajı.', v_profile)
  on conflict (id) do nothing;

end
$seed_reconciliation$;

do $seed_officials$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_field constant uuid := '53570000-0000-4000-8000-000000000002';
  v_federation constant uuid := 'eabd2663-0042-4d4a-9a96-245b69d4dd37';
begin
  if not exists (
    select 1 from auth.users u
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) or not exists (
    select 1 from public.federation_roles
     where profile_id = v_profile and federation_id = v_federation
       and role = 'president' and revoked_at is null
  ) then
    raise exception 'Pro developer official operations demo guard failed';
  end if;

  -- Occupancy writes are audited and must run as the real active manager.
  perform set_config('request.jwt.claim.sub', v_profile::text, true);

  insert into public.turf_occupancy (id, field_id, starts_at, note, created_by)
  values
    ('53574444-7001-4000-8000-000000000001', v_field, date_trunc('day', now() + interval '1 day') + interval '18 hours', '[DEMO] Akşam ligi rezervasyonu', v_profile),
    ('53574444-7002-4000-8000-000000000002', v_field, date_trunc('day', now() + interval '2 days') + interval '20 hours', '[DEMO] Kurumsal maç', v_profile),
    ('53574444-7003-4000-8000-000000000003', v_field, date_trunc('day', now() + interval '3 days') + interval '19 hours', '[DEMO] Kulüp antrenmanı', v_profile),
    ('53574444-7004-4000-8000-000000000004', v_field, date_trunc('day', now() + interval '5 days') + interval '21 hours', '[DEMO] Turnuva hazırlığı', v_profile)
  on conflict (id) do nothing;

  insert into public.federation_offices (id, federation_id, city_code, name)
  values (
    '53574444-7101-4000-8000-000000000001', v_federation, null,
    '[DEMO] TFF Merkez Operasyon Ofisi'
  ) on conflict (id) do nothing;

  insert into public.sport_seasons (id, office_id, label, starts_on, ends_on)
  values (
    '53574444-7201-4000-8000-000000000001',
    '53574444-7101-4000-8000-000000000001',
    '[DEMO] 2026-2027 Resmî Sezon', current_date - 90, current_date + 275
  ) on conflict (id) do nothing;

  insert into public.federation_appointments (
    id, profile_id, office_id, duty, starts_on, ends_on, granted_by
  ) values
    ('53574444-7111-4000-8000-000000000001', v_profile, '53574444-7101-4000-8000-000000000001', 'program_publisher', current_date - 1, current_date + 365, v_profile),
    ('53574444-7112-4000-8000-000000000002', v_profile, '53574444-7101-4000-8000-000000000001', 'result_publisher', current_date - 1, current_date + 365, v_profile),
    ('53574444-7113-4000-8000-000000000003', v_profile, '53574444-7101-4000-8000-000000000001', 'license_registrar', current_date - 1, current_date + 365, v_profile),
    ('53574444-7114-4000-8000-000000000004', v_profile, '53574444-7101-4000-8000-000000000001', 'club_registrar', current_date - 1, current_date + 365, v_profile)
  on conflict (id) do nothing;

end
$seed_officials$;

do $seed_competition$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
  v_federation constant uuid := 'eabd2663-0042-4d4a-9a96-245b69d4dd37';
begin
  if not exists (
    select 1 from public.federation_roles where profile_id = v_profile
      and federation_id = v_federation and role = 'president'
      and revoked_at is null
  ) then
    raise exception 'Pro developer competition demo guard failed';
  end if;

  -- Official tables require the same authenticated appointment context as RPCs.
  perform set_config('request.jwt.claim.sub', v_profile::text, true);

  update public.clubs
     set legal_name = '[DEMO] SwanSport Futbol Kulübü',
         registration_no = 'DEMO-TFF-001',
         registration_sport_code = 'futbol',
         registration_city_code = '34',
         registration_status = 'approved',
         reviewed_by = v_profile,
         reviewed_at = now(),
         review_note = '[DEMO] Staging federasyon fikstürü'
   where id = v_club;

  insert into public.club_sport_registrations (
    club_id, sport_code, registration_no, approved_on
  ) values (v_club, 'futbol', 'DEMO-TFF-001', current_date)
  on conflict (club_id, sport_code) do nothing;

  insert into public.clubs (
    id, name, short_name, city, status, sport_code, legal_name,
    registration_no, registration_sport_code, registration_city_code,
    registration_status, reviewed_by, reviewed_at, review_note
  ) values
    ('53574444-7322-4000-8000-000000000002', '[DEMO] Boğaziçi Spor', 'Boğaziçi', 'İstanbul', 'active', 'futbol', '[DEMO] Boğaziçi Spor Kulübü', 'DEMO-TFF-002', 'futbol', '34', 'approved', v_profile, now(), '[DEMO] Staging federasyon fikstürü'),
    ('53574444-7323-4000-8000-000000000003', '[DEMO] Anadolu Yıldızları', 'Anadolu', 'İstanbul', 'active', 'futbol', '[DEMO] Anadolu Yıldızları Spor Kulübü', 'DEMO-TFF-003', 'futbol', '34', 'approved', v_profile, now(), '[DEMO] Staging federasyon fikstürü'),
    ('53574444-7324-4000-8000-000000000004', '[DEMO] Marmara Atletik', 'Marmara', 'İstanbul', 'active', 'futbol', '[DEMO] Marmara Atletik Spor Kulübü', 'DEMO-TFF-004', 'futbol', '34', 'approved', v_profile, now(), '[DEMO] Staging federasyon fikstürü')
  on conflict (id) do nothing;

  insert into public.club_sport_registrations (
    club_id, sport_code, registration_no, approved_on
  ) values
    ('53574444-7322-4000-8000-000000000002', 'futbol', 'DEMO-TFF-002', current_date),
    ('53574444-7323-4000-8000-000000000003', 'futbol', 'DEMO-TFF-003', current_date),
    ('53574444-7324-4000-8000-000000000004', 'futbol', 'DEMO-TFF-004', current_date)
  on conflict (club_id, sport_code) do nothing;

  insert into public.organizations (
    id, club_id, owner_id, name, kind, sport_code, city_code,
    age_group, starts_on, ends_on, location, description,
    win_points, draw_points, loss_points, is_public, status,
    federation_office_id, sport_season_id, official, published_at
  ) values (
    '53574444-7301-4000-8000-000000000001', null, null,
    '[DEMO] SwanSport İstanbul Profesyonel Ligi', 'league', 'futbol',
    '34', 'Büyükler', current_date - 30, current_date + 120,
    'İstanbul', 'Federasyon, hakem ve puan durumu ekranları için demo lig.',
    3, 1, 0, true, 'running',
    '53574444-7101-4000-8000-000000000001',
    '53574444-7201-4000-8000-000000000001', true, now()
  ) on conflict (id) do nothing;

  insert into public.org_participants (id, org_id, club_id, name, status)
  values
    ('53574444-7311-4000-8000-000000000001', '53574444-7301-4000-8000-000000000001', v_club, '[DEMO] SwanSport Futbol Kulübü', 'accepted'),
    ('53574444-7312-4000-8000-000000000002', '53574444-7301-4000-8000-000000000001', '53574444-7322-4000-8000-000000000002', '[DEMO] Boğaziçi Spor Kulübü', 'accepted'),
    ('53574444-7313-4000-8000-000000000003', '53574444-7301-4000-8000-000000000001', '53574444-7323-4000-8000-000000000003', '[DEMO] Anadolu Yıldızları Spor Kulübü', 'accepted'),
    ('53574444-7314-4000-8000-000000000004', '53574444-7301-4000-8000-000000000001', '53574444-7324-4000-8000-000000000004', '[DEMO] Marmara Atletik Spor Kulübü', 'accepted')
  on conflict (id) do nothing;

  insert into public.org_matches (
    id, org_id, round, home_id, away_id, starts_at, location,
    home_score, away_score, status, result_protocol, result_version
  ) values
    ('53574444-7401-4000-8000-000000000001', '53574444-7301-4000-8000-000000000001', 1, '53574444-7311-4000-8000-000000000001', '53574444-7312-4000-8000-000000000002', now() + interval '3 days', 'SwanSport Stadı', null, null, 'scheduled', null, 0),
    ('53574444-7402-4000-8000-000000000002', '53574444-7301-4000-8000-000000000001', 1, '53574444-7313-4000-8000-000000000003', '53574444-7314-4000-8000-000000000004', now() + interval '5 days', 'Anadolu Sahası', null, null, 'scheduled', null, 0),
    ('53574444-7403-4000-8000-000000000003', '53574444-7301-4000-8000-000000000001', 2, '53574444-7311-4000-8000-000000000001', '53574444-7313-4000-8000-000000000003', now() + interval '10 days', 'SwanSport Stadı', null, null, 'scheduled', null, 0),
    ('53574444-7404-4000-8000-000000000004', '53574444-7301-4000-8000-000000000001', 2, '53574444-7312-4000-8000-000000000002', '53574444-7314-4000-8000-000000000004', now() + interval '12 days', 'Boğaziçi Stadı', null, null, 'scheduled', null, 0),
    ('53574444-7405-4000-8000-000000000005', '53574444-7301-4000-8000-000000000001', 3, '53574444-7314-4000-8000-000000000004', '53574444-7311-4000-8000-000000000001', now() + interval '17 days', 'Marmara Arena', null, null, 'scheduled', null, 0),
    ('53574444-7406-4000-8000-000000000006', '53574444-7301-4000-8000-000000000001', 3, '53574444-7312-4000-8000-000000000002', '53574444-7313-4000-8000-000000000003', now() + interval '19 days', 'Boğaziçi Stadı', null, null, 'scheduled', null, 0)
  on conflict (id) do nothing;

  insert into public.match_officials (
    id, match_id, profile_id, duty, status, assigned_by, responded_at
  ) values
    ('53574444-7501-4000-8000-000000000001', '53574444-7405-4000-8000-000000000005', v_profile, 'head_referee', 'accepted', v_profile, now()),
    ('53574444-7502-4000-8000-000000000002', '53574444-7406-4000-8000-000000000006', v_profile, 'observer', 'assigned', v_profile, null)
  on conflict (id) do nothing;

end
$seed_competition$;

do $seed_platform$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
  v_club constant uuid := '53570000-0000-4000-8000-000000000001';
begin
  if not exists (
    select 1 from auth.users u
      join public.profiles p on p.id = u.id
     where u.id = v_profile
       and lower(u.email) = 'emirbendeniz@gmail.com'
       and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
       and p.is_platform_admin
  ) then
    raise exception 'Pro developer platform demo guard failed';
  end if;

  insert into public.support_tickets (
    id, profile_id, club_id, subject, body, context, status, assigned_to
  ) values
    ('53574444-8101-4000-8000-000000000001', v_profile, v_club, '[DEMO] Mobil bildirim kontrolü', 'Staging cihazında bildirim yönlendirmesi kontrol ediliyor.', '{"demo":true,"app":"swansport_pro","platform":"ios"}', 'under_review', v_profile),
    ('53574444-8102-4000-8000-000000000002', v_profile, v_club, '[DEMO] Muhasebe raporu talebi', 'Aylık bütçe görünümü için demo kayıt.', '{"demo":true,"area":"accounting"}', 'new', null)
  on conflict (id) do nothing;

end
$seed_platform$;

do $seed_inbox$
declare
  v_profile constant uuid := '78d123f0-85c8-43d1-a216-67614c90d5a1';
begin
  if not exists (
    select 1 from auth.users u where u.id = v_profile
      and lower(u.email) = 'emirbendeniz@gmail.com'
      and coalesce((u.raw_app_meta_data ->> 'pro_workspace_preview')::boolean, false)
  ) then
    raise exception 'Pro developer inbox demo guard failed';
  end if;

  insert into public.notifications (
    id, profile_id, kind, title, body, entity_type, entity_id, read_at
  ) values
    ('53574444-8001-4000-8000-000000000001', v_profile, 'referee_assignment', '[DEMO] Yeni hakem görevi', 'Marmara Atletik - SwanSport FK maçına başhakem olarak atandınız.', 'org_match', '53574444-7405-4000-8000-000000000005', null),
    ('53574444-8002-4000-8000-000000000002', v_profile, 'expense_approval', '[DEMO] Gider onayı bekliyor', 'Deplasman otobüsü gideri onay bekliyor.', 'expense', '53574444-6403-4000-8000-000000000003', null),
    ('53574444-8003-4000-8000-000000000003', v_profile, 'bank_unmatched', '[DEMO] Eşleşmeyen banka hareketi', 'İki banka hareketi mutabakat bekliyor.', 'bank_import', '53574444-6801-4000-8000-000000000001', null),
    ('53574444-8004-4000-8000-000000000004', v_profile, 'attendance_reminder', '[DEMO] Yoklama hatırlatması', 'Taktik antrenman yoklaması yarın açılacak.', 'event', '53574444-3001-4000-8000-000000000001', null),
    ('53574444-8005-4000-8000-000000000005', v_profile, 'document_expiry', '[DEMO] Belge süresi yaklaşıyor', 'Tesis sigorta poliçesinin süresi 45 gün içinde dolacak.', 'document', '53574444-5002-4000-8000-000000000002', null),
    ('53574444-8006-4000-8000-000000000006', v_profile, 'announcement', '[DEMO] Kulüp duyurusu', 'Hafta programı yayınlandı.', 'announcement', '53574444-4001-4000-8000-000000000001', now() - interval '1 day'),
    ('53574444-8007-4000-8000-000000000007', v_profile, 'match_live', '[DEMO] Resmî fikstür yayınlandı', 'SwanSport FK - Anadolu Yıldızları maçı programa eklendi.', 'org_match', '53574444-7403-4000-8000-000000000003', now() - interval '2 days'),
    ('53574444-8008-4000-8000-000000000008', v_profile, 'support', '[DEMO] Destek kaydı güncellendi', 'Demo destek kaydınız incelemeye alındı.', 'support_ticket', '53574444-8101-4000-8000-000000000001', null)
  on conflict (id) do nothing;

  insert into public.launch_waitlist (id, email, role, sport_code, club_or_city, source)
  values
    ('53574444-8201-4000-8000-000000000001', 'demo-antrenor-1@swansport.test', 'coach', 'futbol', 'İstanbul', 'pro-demo-seed'),
    ('53574444-8202-4000-8000-000000000002', 'demo-hakem-1@swansport.test', 'referee', 'futbol', 'Ankara', 'pro-demo-seed'),
    ('53574444-8203-4000-8000-000000000003', 'demo-kulup-1@swansport.test', 'club_admin', 'basketbol', 'İzmir', 'pro-demo-seed')
  on conflict (email) do nothing;

  insert into public.platform_audit_logs (
    id, actor_id, action, entity_type, entity_id, old_state, new_state
  ) values
    ('53574444-8301-4000-8000-000000000001', v_profile, 'demo_seed_applied', 'staging_dataset', 'pro-developer-demo-v1', null, '{"status":"active","areas":["club","finance","facility","federation","referee","platform"]}'),
    ('53574444-8302-4000-8000-000000000002', v_profile, 'demo_role_reviewed', 'profile', v_profile::text, '{"preview":false}', '{"preview":true}'),
    ('53574444-8303-4000-8000-000000000003', v_profile, 'demo_fixture_verified', 'staging_dataset', 'pro-developer-demo-v1', null, '{"deterministic":true,"reversible":true}')
  on conflict (id) do nothing;
end
$seed_inbox$;
