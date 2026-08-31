-- 0041 — Kort kullanım ölçümü
--
-- NEDEN: belediye görüşmesine sunum değil **çalışan bir sistem ve sayılar**
-- götürülecek. "Kortları dijitalleştirelim" demekle "şu kadar kişi şu kadar
-- saat aldı, gelmeme oranı şu" demek arasında pazarlık gücü farkı var.
--
-- Bu sayılar sonradan geriye dönük üretilemez diye endişe edilmişti; öyle
-- değil — `court_slots` zaten her kutuyu kaydediyor. Eksik olan tek şey
-- toplayan bir sorguydu. Bu migration yeni tablo ya da sütun eklemiyor,
-- yalnızca okuma ekliyor.
--
-- Kort kullanım profili kişisel veriye yakın (kim, ne zaman, nerede).
-- İkisi de yalnızca platform yöneticisine açık.

-- ---------------------------------------------------------------------------
-- Genel özet
-- ---------------------------------------------------------------------------
create or replace function public.court_usage_stats(p_days int default 30)
returns table (
  slots_total     int,      -- alınan kutu
  slots_done      int,      -- gerçekten oynanmış
  slots_expired   int,      -- alınıp gelinmemiş
  slots_cancelled int,      -- iptal edilmiş
  unique_players  int,      -- tekil kutu sahibi
  total_people    int,      -- sahipler + kabul edilen katılımcılar + misafirler
  no_show_pct     numeric,
  checkin_pct     numeric,
  peak_hour       int       -- yerel saatte en yoğun saat
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_platform_admin() then
    raise exception 'Kort ölçümleri yalnızca platform yöneticisine açık';
  end if;

  return query
  with win as (
    select * from public.court_slots
     where starts_at >= now() - (greatest(p_days, 1) || ' days')::interval
  ),
  -- Gelmeme oranının paydası "alınan her kutu" DEĞİL.
  --
  -- İptal edilenler dışarıda: iptal cezasız ve teşvik edilen davranış
  -- (0035'in kuralı — "iptal cezalandırılırsa kimse iptal etmez, sessizce
  -- gelmez"). Onu gelmeme gibi saymak sistemi doğru kullanan kişiyi kötü
  -- gösterirdi. Saati henüz gelmemiş kutular da dışarıda: sonucu belli değil.
  decided as (
    select * from win where status in ('done', 'expired')
  )
  select
    (select count(*)::int from win),
    (select count(*)::int from win where status = 'done'),
    (select count(*)::int from win where status = 'expired'),
    (select count(*)::int from win where status = 'cancelled'),
    (select count(distinct owner_id)::int from win),
    -- "Kaç kişi kortta oldu" — belediyenin asıl sorusu bu, kutu sayısı değil.
    -- Misafirler uygulamada olmayan arkadaşlar; onları saymazsak sistemin
    -- ulaştığı insan sayısı olduğundan az görünür.
    (select (
        (select count(distinct owner_id) from win)
      + (select count(distinct p.profile_id)
           from public.court_slot_players p
           join win w on w.id = p.slot_id
          where p.status = 'accepted')
      + (select coalesce(sum(guest_count), 0) from win)
     )::int),
    (select case when count(*) = 0 then 0::numeric
                 else round(100.0 * count(*) filter (where status = 'expired')
                            / count(*), 1) end
       from decided),
    (select case when count(*) = 0 then 0::numeric
                 else round(100.0 * count(*) filter (where checked_in_at is not null)
                            / count(*), 1) end
       from win),
    (select coalesce((
       select extract(hour from starts_at at time zone 'Europe/Istanbul')::int
         from win
        group by 1
        order by count(*) desc, 1
        limit 1), 0));
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Kort kırılımı — hangi kort ne kadar kullanılıyor
-- ---------------------------------------------------------------------------
create or replace function public.court_usage_by_court(p_days int default 30)
returns table (
  court_id    uuid,
  court_name  text,
  venue       text,
  slots_total int,
  slots_done  int,
  no_show_pct numeric,
  -- Doluluk: alınan kutu / açık olunan saat sayısı. Kortlar 08:00–23:00
  -- aralığında, gece yarısını aşan yok — halı sahadan farkı bu, orada
  -- `closes_at` 24:00 olabiliyor ve aynı hesap yanlış çıkardı.
  fill_pct    numeric
)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_platform_admin() then
    raise exception 'Kort ölçümleri yalnızca platform yöneticisine açık';
  end if;

  return query
  with win as (
    select * from public.court_slots
     where starts_at >= now() - (greatest(p_days, 1) || ' days')::interval
  )
  select
    c.id,
    c.name,
    c.venue,
    count(w.id)::int,
    count(w.id) filter (where w.status = 'done')::int,
    case when count(w.id) filter (where w.status in ('done', 'expired')) = 0
         then 0::numeric
         else round(100.0 * count(w.id) filter (where w.status = 'expired')
                    / count(w.id) filter (where w.status in ('done', 'expired')), 1)
    end,
    case when extract(epoch from (c.closes_at - c.opens_at)) <= 0
         then 0::numeric
         else round((100.0 * count(w.id)
              / (greatest(p_days, 1)
                 * (extract(epoch from (c.closes_at - c.opens_at)) / 3600)))::numeric, 1)
    end
    from public.courts c
    left join win w on w.court_id = c.id
   where c.active
   group by c.id, c.name, c.venue, c.opens_at, c.closes_at
   -- Kullanılmayan kort de listede kalsın (left join): "hiç alınmamış" bir
   -- kort, belediye görüşmesinde en az dolu kort kadar bilgi taşıyor.
   order by count(w.id) desc, c.name;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- İzinler
--
-- 0028'in dersi: `public` rolünü unutma. Yalnızca `anon` ve `authenticated`'dan
-- almak yetmiyor, izin `PUBLIC`'ten miras alınıyor.
-- ---------------------------------------------------------------------------
revoke execute on function public.court_usage_stats(int) from public, anon;
revoke execute on function public.court_usage_by_court(int) from public, anon;

-- `authenticated`'a veriliyor ama gövdedeki `is_platform_admin()` kontrolü
-- asıl kapı: rol bazlı grant kişi ayrımı yapamıyor.
grant execute on function public.court_usage_stats(int) to authenticated;
grant execute on function public.court_usage_by_court(int) to authenticated;
