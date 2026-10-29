-- 0135 — SwanSport Pro Faz 2 çevrimiçi yoklama görünürlük kapısı
--
-- Bu bayrak güvenlik yetkisi vermez. Yoklama yazma yetkisi mevcut RLS/RPC
-- kontrollerinde kalır. Mevcut çevrimdışı ve antrenman bayraklarının yayın
-- kademelerine dokunulmaz.

set local lock_timeout = '15s';

do $phase2$
declare
  inserted_now boolean := false;
begin
  -- FAQ yayın tetikleyicisi nedeniyle önce güvenli admins kademesinde ekle.
  insert into public.feature_flags (key, audience, label, description)
  values (
    'attendance_operations',
    'admins',
    'Çevrimiçi yoklama işlemleri',
    'Kulüp yöneticisi ve antrenörlerin mevcut RLS/RPC kurallarıyla çevrimiçi yoklama alması.'
  )
  on conflict (key) do nothing
  returning true into inserted_now;

  insert into public.faq_entries (
    question,
    answer,
    category,
    audience,
    sort_order,
    route,
    feature
  )
  select
    'İnternet varken yoklama nasıl alınır?',
    'Yoklama ekranından etkinliği seç, sporcuların durumunu işaretle ve kaydet. Başka bir görevli aynı kaydı değiştirdiyse uygulama çakışmayı gösterir; güncel kadroyu yenilemeden kayıt ezilmez. Çevrimdışı hazırlama ve kuyruk ayrı bir özelliktir.',
    'Kulüp',
    'club_staff',
    190,
    '/attendance',
    'attendance_operations'
  where not exists (
    select 1
      from public.faq_entries
     where feature = 'attendance_operations'
       and question = 'İnternet varken yoklama nasıl alınır?'
  );

  -- Yalnızca bu çalıştırmada oluşturulan satırı genel kullanıma aç. Migration
  -- tekrarında operatörün sonradan seçtiği off/admins/testers değeri korunur.
  if coalesce(inserted_now, false) then
    update public.feature_flags
       set audience = 'everyone'
     where key = 'attendance_operations'
       and audience = 'admins';
  end if;
end
$phase2$;
