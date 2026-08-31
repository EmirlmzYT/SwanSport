-- 0040 gerçekten uygulandı mı? Supabase SQL Editor'e yapıştır.
-- Üç satır döner; hepsinde ilk kelime iyi haber olmalı.

select 'tetikleyici trg_notify_direct_message' as kontrol,
       case when exists (
              select 1
                from pg_trigger t
                join pg_class c on c.oid = t.tgrelid
                join pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public'
                 and c.relname = 'direct_messages'
                 and t.tgname = 'trg_notify_direct_message'
                 and not t.tgisinternal)
            then 'VAR'
            else 'YOK - 0040 uygulanmamis, DM bildirimi dusmez'
       end as sonuc

union all

-- 0040 `send_club_message`'in elle yazdigi notifications insert'ini kaldirdi.
-- Kalmissa ayni mesaj icin iki bildirim gelir (tetikleyici + elle yazan).
select 'send_club_message elle bildirim yazmiyor',
       case when exists (
              select 1
                from pg_proc p
                join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public'
                 and p.proname = 'send_club_message'
                 and pg_get_functiondef(p.oid) ilike '%into public.notifications%')
            then 'HALA YAZIYOR - cift bildirim gelir'
            else 'TEMIZ'
       end

union all

-- HTTP 300 tuzagi: donus tipi degisen bir fonksiyon `create or replace` ile
-- degil, yeni bir imza olarak eklenmis olabilir. Iki imza kalirsa PostgREST
-- hangisini cagiracagini bilemez ve 300 doner.
select 'tek imza: ' || p.proname,
       case when count(*) = 1
            then 'TAMAM'
            else count(*) || ' imza - eskisi dusmemis, drop et'
       end
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('notify_direct_message', 'send_club_message',
                     'request_turf_slot', 'court_usage_stats',
                     'court_usage_by_court')
 group by p.proname;
