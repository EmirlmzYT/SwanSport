-- Public RSS metadata only; private/admin source-table permissions stay intact.
set local lock_timeout = '15s';
create or replace function public.public_news_sources()
returns table(id uuid,name text,url text,active boolean)
language sql stable security definer set search_path=public as $$
 select s.id,s.name,s.url,s.active from public.rss_sources s
 where s.active order by s.name,s.id
$$;
revoke all on function public.public_news_sources() from public,anon,authenticated;
grant execute on function public.public_news_sources() to anon,authenticated;

insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Misafir olarak neleri görebilirim?',
 'Hesap açmadan haberleri, kort ve sahaları, yayımlanmış federasyon faaliyet programlarını inceleyebilirsin. Kulüp başvurusu, katılım yanıtı, mesaj, ilan ve rezervasyon için Giriş Yap / Kayıt Ol seçeneğini kullan.',
 'Genel','everyone',100,'/kesfet'
where not exists(select 1 from public.faq_entries where question='Misafir olarak neleri görebilirim?');
insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Kulübe başvururken neden kimlik doğrulaması isteniyor?',
 'Resmi kulüp kadrosuna katılmak için kimliğin ve başvurduğun branştaki sporcu lisansı veya antrenör belgen platform tarafından onaylanmalıdır. Doğrulama ekranında Kimlik bölümünden belgeni yükle; spor belgesi için branş ve bitiş tarihini seç. Beyan edilen TCKN veya rol onay yerine geçmez. Veli bağlantısı kimlik ve geçerli davetle kurulur; veli için lisans gerekmez.',
 'Genel','everyone',101,'/dogrulama'
where not exists(select 1 from public.faq_entries where question='Kulübe başvururken neden kimlik doğrulaması isteniyor?');
