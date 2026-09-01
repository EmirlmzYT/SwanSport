-- ---------------------------------------------------------------------------
-- 0061 — Mali iş kuyruğu, kulüp operasyon merkezi, bildirimler ve bayraklar
--
-- Kaynak tabloların hepsi 0055-0060'ta kurulduğu için özet burada **bir kez**
-- yazılıyor. Her migration'da imza değiştirmek HTTP 300 tuzağını altı kez
-- açardı (AGENTS.md).
--
-- İKİ AYRI ÖZET, BİLEREK:
--
--   acc_operations_summary    → mali. Muhasebeciye AÇIK. Sporcu, veli,
--                               isim ve sportif veri yok.
--   club_operations_summary   → kulüp operasyonu. Yalnızca kulüp personeli.
--                               Üyelik, belge, yoklama, RSVP içeriyor.
--
-- Tek fonksiyonda birleştirip alanları role göre boşaltmak, gizliliği
-- çağıranın doğru parametreyi geçmesine bağlardı. Ayrı fonksiyon, ayrı izin.
-- ---------------------------------------------------------------------------

-- Dönüş tipi değiştiği için `create or replace` yetmez; önce düşür.
drop function if exists public.acc_operations_summary(uuid);

create or replace function public.acc_operations_summary(p_club uuid)
returns table (
  draft_expense_count      bigint,
  draft_expense_total      numeric,
  pending_payment_count    bigint,
  pending_payment_total    numeric,
  overdue_invoice_count    bigint,
  overdue_invoice_total    numeric,
  unlinked_income_count    bigint,
  unlinked_income_total    numeric,
  unlinked_expense_count   bigint,
  unlinked_expense_total   numeric,
  negative_account_count   bigint,
  negative_account_total   numeric,
  missing_receipt_count    bigint,
  commitment_due_count     bigint,
  commitment_due_total     numeric,
  pending_approval_count   bigint,
  pending_approval_total   numeric,
  bank_unmatched_count     bigint,
  bank_unmatched_total     numeric,
  close_blocker_count      bigint)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  -- `security definer` RLS'i atlar; yetki kontrolü gövdede olmak zorunda
  -- (AGENTS.md 0049 dersi). Platform yöneticisi de kapsam dışı bırakıldı:
  -- mali veriye erişimi kulüple ilişkisinden gelmeli.
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün mali özetini görme yetkiniz yok';
  end if;

  return query
  with
  draft as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.status = 'draft'),
  pend_pay as (
    select count(*) c, coalesce(sum(p.amount), 0) t
      from public.payments p
     where p.club_id = p_club and p.status = 'pending'),
  overdue as (
    -- Gecikmiş aidat `invoices`'ten geliyor: vade orada tutuluyor.
    -- `payments` tablosunda `due_date` sütunu YOK ve `unpaid` durumu da yok
    -- (`pending|confirmed|rejected`) — ilk taslak oradan okumaya çalışıyordu
    -- ve çağrıldığı anda patlardı.
    select count(*) c, coalesce(sum(i.amount), 0) t
      from public.invoices i
     where i.club_id = p_club and i.status <> 'paid'
       and i.due_date is not null and i.due_date < current_date),
  unlinked_in as (
    select count(*) c, coalesce(sum(x.amount), 0) t from (
      select p.amount from public.payments p
       where p.club_id = p_club and p.status = 'confirmed'
         and p.account_id is null
      union all
      select d.amount from public.donations d
       where d.club_id = p_club and d.status = 'confirmed'
         and d.account_id is null) x),
  unlinked_out as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.status = 'complete'
       and e.account_id is null),
  neg as (
    -- Bakiye matematiği burada tekrarlanmıyor. `acc_account_balances` gelir
    -- tarafında `confirmed`, gider tarafında `complete` süzüyor; elle
    -- yeniden yazan ilk taslak taslak ve reddedilenleri de sayıyordu.
    select count(*) c, coalesce(sum(b.balance), 0) t
      from public.acc_account_balances(p_club) b
     where b.balance < 0),
  no_receipt as (
    select count(*) c
      from public.expenses e
     where e.club_id = p_club and e.status = 'complete'
       and coalesce(trim(e.receipt_path), '') = ''),
  commit_due as (
    select count(*) c, coalesce(sum(o.amount), 0) t
      from public.recurring_occurrences o
     where o.club_id = p_club and o.status = 'pending'
       and o.due_on <= current_date + 7),
  approvals as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.approval_status = 'pending'),
  bank as (
    select count(*) c, coalesce(sum(t.amount), 0) t
      from public.bank_transactions t
     where t.club_id = p_club and t.match_status = 'unmatched'),
  blockers as (
    -- Açık dönemin kapanışını engelleyen madde sayısı. Açık dönem yoksa 0.
    select coalesce((
      select count(*) from public.finance_periods fp
      cross join lateral public.period_close_checklist(
        p_club, fp.period_from, fp.period_to) ck
       where fp.club_id = p_club
         and fp.status in ('open', 'preparing', 'review')
         and current_date > fp.period_to
         and ck.blocking and ck.qty > 0), 0) c)
  select d.c, d.t, pp.c, pp.t, ov.c, ov.t, ui.c, ui.t, uo.c, uo.t,
         n.c, n.t, nr.c, cd.c, cd.t, ap.c, ap.t, bk.c, bk.t, bl.c
    from draft d, pend_pay pp, overdue ov, unlinked_in ui, unlinked_out uo,
         neg n, no_receipt nr, commit_due cd, approvals ap, bank bk,
         blockers bl;
end;
$fn$;

revoke execute on function public.acc_operations_summary(uuid) from public, anon;
grant execute on function public.acc_operations_summary(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- KULÜP OPERASYON MERKEZİ
--
-- Yalnızca kulüp personeli. Muhasebeci BU FONKSİYONU ÇAĞIRAMAZ — içinde
-- üyelik, belge ve yoklama sayıları var ve bunlar sportif/kişisel veri.
--
-- BİLİNEN EKSİK — TESİS ÇAKIŞMASI: planda isteniyor ama hesaplanamıyor.
-- Bu şemada tesis rezervasyonu diye bir tablo yok; `facilities` yalnızca ad,
-- tür ve doluluk yüzdesi tutuyor, `events.place` ise serbest metin. Serbest
-- metin eşleştirerek "çakışma" üretmek, olmayan bir çakışmayı varmış gibi
-- göstermenin en kolay yolu olurdu. Rezervasyon tablosu geldiğinde eklenecek.
-- ---------------------------------------------------------------------------
create or replace function public.club_operations_summary(p_club uuid)
returns table (
  pending_membership_count bigint,
  expiring_document_count  bigint,
  unmarked_event_count     bigint,
  low_rsvp_event_count     bigint,
  open_report_count        bigint,
  pending_store_count      bigint)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulübün operasyon özetini görme yetkiniz yok';
  end if;

  return query
  with
  memberships as (
    select count(*) c from public.club_applications a
     where a.club_id = p_club and a.status = 'pending'),
  docs as (
    select count(*) c from public.documents d
     where d.club_id = p_club
       and d.expires_on is not null
       and d.expires_on between current_date and current_date + 30),
  unmarked as (
    -- Başlamış ama yoklaması hiç alınmamış etkinlikler, son 14 gün.
    select count(*) c from public.events e
     where e.club_id = p_club
       and e.starts_at < now()
       and e.starts_at > now() - interval '14 days'
       and not exists (select 1 from public.attendance a
                        where a.event_id = e.id)),
  low_rsvp as (
    -- Yaklaşan antrenmanlarda yanıt oranı %50'nin altında. Kadrosu boş
    -- takımlar sayılmıyor: sıfıra bölme ve anlamsız uyarı üretiyordu.
    select count(*) c from public.events e
     where e.club_id = p_club
       and e.starts_at between now() and now() + interval '3 days'
       and e.team_id is not null
       and (select count(*) from public.team_members tm
             where tm.team_id = e.team_id) > 0
       and (select count(*) from public.event_rsvps r
             where r.event_id = e.id)::numeric
           < 0.5 * (select count(*) from public.team_members tm
                     where tm.team_id = e.team_id)::numeric),
  reports as (
    select count(*) c from public.content_reports r
     where r.status = 'open'
       and public.is_platform_admin()),
  stores as (
    select count(*) c from public.stores s
     where s.status = 'pending'
       and public.is_platform_admin())
  select m.c, d.c, u.c, l.c, rp.c, st.c
    from memberships m, docs d, unmarked u, low_rsvp l, reports rp, stores st;
end;
$fn$;

revoke execute on function public.club_operations_summary(uuid) from public, anon;
grant execute on function public.club_operations_summary(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- BİLDİRİM ROTALARI
--
-- 0052'deki 23 eşlemenin HEPSİ korunuyor, üstüne yedi yeni. Bu fonksiyon beş
-- migration'da baştan yazıldı ve 0039 dört eşlemeyi sessizce düşürdü;
-- belirtisi yok, kullanıcı yanlış ekrana gidiyor. `tools/check_push_routes.py`
-- bunu denetliyor.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    -- 0061 — mali operasyon
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    else '/bildirimler'
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- NEGATİF BAKİYE UYARISI
--
-- Günde bir. `reminder_log` tekilliği hesap bazında: aynı hesap için aynı
-- gün ikinci bildirim gitmiyor. Hesap artıya dönerse ertesi gün susuyor.
-- ---------------------------------------------------------------------------
create or replace function public.send_finance_alerts()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with clubs_with_accounts as (
    select distinct ca.club_id from public.cash_accounts ca where ca.active
  ),
  neg as (
    select c.club_id, b.account_id, b.name, b.balance
      from clubs_with_accounts c
      cross join lateral public.acc_account_balances(c.club_id) b
     where b.balance < 0
  ),
  targets as (
    select distinct n.account_id, n.name, n.balance, m.profile_id
      from neg n
      join public.club_memberships m
        on m.club_id = n.club_id and m.role = 'club_admin'
       and m.status = 'active'
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'account_negative', t.account_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'account_negative', 'Hesap negatif bakiyede',
           t.name || ' · ' ||
             trim(to_char(t.balance, 'FM999G999G999')) || ' TL',
           'cash_account', f.entity_id
      from fresh f
      join targets t
        on t.account_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_finance_alerts', '0 8 * * *',
  $cron$select public.send_finance_alerts();$cron$);

-- ---------------------------------------------------------------------------
-- ÖZELLİK BAYRAKLARI — kademeli yayın
--
-- Altısı da `admins`'te başlıyor. Hiçbiri denenmedi; pazaryerinde aynı hata
-- yapıldı (0053 notu) ve bu sefer baştan doğru sıraya konuyor.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('finance_operations_center', 'admins', 'Mali operasyon merkezi',
   'Mali iş kuyruğu, anonim operasyon özeti ve konsol giriş paneli.'),
  ('recurring_expenses', 'admins', 'Tekrarlayan giderler',
   'Kira, lisans, bakım gibi düzenli giderler ve vade uyarıları.'),
  ('bank_reconciliation', 'admins', 'Banka mutabakatı',
   'CSV ekstre yükleme ve defter kayıtlarıyla eşleştirme.'),
  ('club_budgeting', 'admins', 'Bütçe ve nakit tahmini',
   'Kulüp/takım/tesis/etkinlik bütçesi ve 30-60-90 gün nakit tahmini.'),
  ('period_closing', 'admins', 'Dönem kapanışı',
   'Mali dönem kapanışı, kontrol listesi ve düzeltme kayıtları.'),
  ('club_operations_center', 'admins', 'Kulüp operasyon merkezi',
   'Mali ve sportif bekleyen işlerin tek kuyrukta birleşimi.')
on conflict (key) do nothing;
