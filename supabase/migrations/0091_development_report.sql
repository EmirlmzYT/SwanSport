-- On-demand private development report; no duplicate performance ledger/snapshot table.
set local lock_timeout='15s';
create or replace function public.development_report_athletes(p_query text default '',p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Oturum gerekli.'; end if;
 if not exists(select 1 from public.my_feature_flags() f where f.key='development_report') then raise exception 'Gelişim raporu şu anda hesabına açık değil.'; end if;
 if p_offset is null or p_offset<0 or p_offset>100000 or p_query is null or length(p_query)>100 then raise exception 'Geçersiz arama.'; end if;
 with eligible as (
  select a.id,trim(a.first_name||' '||a.last_name) full_name,a.club_id,c.name club_name
  from public.athletes a left join public.clubs c on c.id=a.club_id
  where public.can_view_athlete_performance(a.id)
   and strpos(translate(lower(a.first_name||' '||a.last_name||' '||coalesce(c.name,'')),'ıİşŞğĞüÜöÖçÇ','iissgguuoocc'),
     translate(lower(trim(p_query)),'ıİşŞğĞüÜöÖçÇ','iissgguuoocc'))>0
  order by trim(a.first_name||' '||a.last_name),a.id offset p_offset limit 41
 ) select jsonb_build_object('athletes',coalesce((select jsonb_agg(to_jsonb(e) order by e.full_name,e.id) from (select * from eligible order by full_name,id limit 40) e),'[]'::jsonb),'has_more',(select count(*)>40 from eligible)) into result;
 return result;
end $fn$;

create or replace function public.athlete_development_report(p_athlete uuid,p_from date,p_to date)
returns jsonb language plpgsql stable security definer set search_path=public as $fn$
declare result jsonb; today date:=(now() at time zone 'Europe/Istanbul')::date;
begin
 -- Uniform denial for missing/unauthorized athletes, including pure accountants.
 if auth.uid() is null or not coalesce(public.can_view_athlete_performance(p_athlete),false) then raise exception 'Bu rapora erişilemiyor.'; end if;
 if not exists(select 1 from public.my_feature_flags() f where f.key='development_report') then raise exception 'Gelişim raporu şu anda hesabına açık değil.'; end if;
 if p_from is null or p_to is null or p_to<p_from or p_to-p_from>365 or p_to>today then raise exception 'Geçerli ve en fazla 366 günlük bir dönem seç.'; end if;
 with athlete as (select a.id,a.club_id,trim(a.first_name||' '||a.last_name) full_name,c.name club_name from public.athletes a left join public.clubs c on c.id=a.club_id where a.id=p_athlete),
 att as (
  select at.status from public.attendance at join public.events e on e.id=at.event_id join athlete a on a.id=at.athlete_id and at.club_id=a.club_id and e.club_id=a.club_id
  where (e.starts_at at time zone 'Europe/Istanbul')::date between p_from and p_to and e.starts_at<=now()
 ), counts as (select count(*) filter(where status='present')::int present,count(*) filter(where status='late')::int late,
  count(*) filter(where status='absent')::int absent,count(*) filter(where status='excused')::int excused from att),
 metrics as (
  select t.category,t.test_name,t.unit,t.lower_is_better,count(*)::int sample_count,
   (array_agg(t.value order by t.test_date,t.created_at,t.id))[1] first_value,
   (array_agg(t.value order by t.test_date desc,t.created_at desc,t.id desc))[1] last_value,
   min(t.test_date) first_date,max(t.test_date) last_date
  from public.performance_tests t where t.athlete_id=p_athlete and t.test_date between p_from and p_to
  group by t.category,t.test_name,t.unit,t.lower_is_better
 ), goals as (
  select g.id,g.title,g.category,g.progress,g.status,g.target_date,
   (g.created_at at time zone 'Europe/Istanbul')::date created_on,
   (g.test_name is not null and g.baseline_value is not null and g.target_value is not null) measured
  from public.development_goals g where g.athlete_id=p_athlete and (g.created_at at time zone 'Europe/Istanbul')::date<=p_to
 )
 select jsonb_build_object(
  'athlete',(select to_jsonb(a) from athlete a),'from',p_from,'to',p_to,
  'attendance',(select jsonb_build_object('present',c.present,'late',c.late,'absent',c.absent,'excused',c.excused,
    'rate',round(100.0*(c.present+c.late)/nullif(c.present+c.late+c.absent,0),1),
    'unlinked',(select count(*) from public.attendance old join athlete a on old.athlete_id=a.id and old.club_id=a.club_id where old.event_id is null and (old.taken_at at time zone 'Europe/Istanbul')::date between p_from and p_to)) from counts c),
  'metrics',coalesce((select jsonb_agg(to_jsonb(m) order by m.category,m.test_name,m.unit,m.lower_is_better) from metrics m),'[]'::jsonb),
  'goals',coalesce((select jsonb_agg(to_jsonb(g) order by g.created_on,g.id) from goals g),'[]'::jsonb)
 ) into result;
 -- Fingerprint is a change detector for preview/copy, never authorization.
 return result||jsonb_build_object('fingerprint',md5(result::text),'generated_at',now());
end $fn$;
revoke all on function public.development_report_athletes(text,int) from public,anon;
revoke all on function public.athlete_development_report(uuid,date,date) from public,anon;
grant execute on function public.development_report_athletes(text,int) to authenticated;
grant execute on function public.athlete_development_report(uuid,date,date) to authenticated;
insert into public.feature_flags(key,audience,label,description) values('development_report','admins','Dönem gelişim raporu','Yetkili sporcu/veli/personel için gerçek dönem yoklaması, karşılaştırılabilir ölçümler ve açıkça güncel hedef durumu.') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Dönem gelişim raporunu nasıl hazırlarım?',
 'Profil > Yönetim > Gelişim Raporu ekranında erişebildiğin sporcuyu ve en fazla 366 günlük tarih aralığını seç. Devam oranı yalnız kayıtlı etkinlik yoklamalarından hesaplanır: geç gelenler katılmış sayılır, izinliler paydaya girmez. Kaydedilmemiş yoklamalar devamsızlık sayılmaz. Etkinliksiz eski kayıtlar ayrıca gösterilir. Ölçümler yalnız aynı test, kategori, birim ve ölçüm yönünde karşılaştırılır. Hedefler dönem sonuna kadar açılan hedeflerin bugünkü durumudur; geçmiş yüzdesi değildir. Rapor metnini önizleyip kopyalayabilirsin; ad ve kulüp varsayılan olarak metne eklenmez. Kopyalarken erişim ve verinin değişip değişmediği yeniden kontrol edilir.',
 'Sporcu','everyone',196,'/gelisim-raporu','development_report'
where not exists(select 1 from public.faq_entries where feature='development_report' and active);
