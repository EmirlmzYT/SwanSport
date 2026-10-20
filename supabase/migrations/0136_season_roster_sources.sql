set local lock_timeout = '15s';
-- The existing open_club_season remains the sole atomic writer.
create or replace function public.season_roster_sources(p_club uuid)
returns jsonb language plpgsql stable security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null or not coalesce(is_club_admin(p_club),false) or
 not exists(select 1 from my_feature_flags() f where f.key='season_setup') then
  raise exception 'Sezon hazırlığı için aktif kulüp yöneticisi yetkisi gerekli.' using errcode='42501';
 end if;
 return coalesce((select jsonb_agg(to_jsonb(q)) from (
  select s.id season_id,s.label season_label,t.id team_id,t.name team_name,
   jsonb_agg(jsonb_build_object('id',a.id,'name',concat_ws(' ',a.first_name,a.last_name)) order by a.last_name,a.first_name,a.id) athletes
  from seasons s join team_memberships m on m.season_id=s.id join teams t on t.id=m.team_id and t.club_id=s.club_id
  join athletes a on a.id=m.athlete_id and a.club_id=s.club_id and a.status='active'
  where s.club_id=p_club group by s.id,s.label,s.starts_on,t.id,t.name
  order by s.starts_on desc,t.name,t.id limit 100
 ) q),'[]'::jsonb);
end $$;
revoke all on function public.season_roster_sources(uuid) from public,anon;
grant execute on function public.season_roster_sources(uuid) to authenticated;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Önceki sezonun kadrosunu yeni sezona nasıl taşırım?',
 'Sezon Açılışı ekranında Takım ve kadro adımına gel. Önceki sezon/takım listesinden bir kadro seç; aktif sporcular seçime alınır. Yeni takım adına farklı bir ad ver; seçimi gözden geçirip ekleme/çıkarma yap. Son kontrolden sonra mevcut atomik sezon hazırlığı yeni sezonu, yeni takımı ve seçtiğin kadroyu birlikte kaydeder. Eski sezon, takım, yoklama, lisans ve aidat kayıtları değişmez. Hesabı olmayan çocuklar da aktif sporcu kaydıyla taşınabilir. En fazla 200 sporcu seçilir.',
 'Kulüp','club_staff',212,'/sezon-acilisi','season_setup'
where not exists(select 1 from public.faq_entries where question='Önceki sezonun kadrosunu yeni sezona nasıl taşırım?');
