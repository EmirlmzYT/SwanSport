set local lock_timeout = '15s';
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Sporcu gelişim geçmişimde hangi kayıtlar yer alır?',
  'Kulüp üyeliği, başarılar, yayımlanmış vitrin videoları, kişisel kilometre taşları ve katılım özetleri izinli kaynaklardan gösterilir. Kayıt olmayan dönemde gelişim puanı uydurulmaz.',
  'profil','athlete',138,'/swan-id','athlete_journey'
where not exists(select 1 from public.faq_entries where feature='athlete_journey' and active);

-- 0129 attaches this feature to an existing FAQ through UPDATE. Keep explicit,
-- idempotent coverage for clean installs and the static release check as well.
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Federasyonun yayımladığı resmi bültenleri nasıl okurum?',
  'Federasyon Yayın Merkezi içindeki bültenlerden yayımlanmış duyuruları okuyabilirsin. Özel disiplin gerekçeleri ve hakem raporları kamuya açılmaz; görünürlük yetki ve özellik kapılarına bağlıdır.',
  'federasyon','everyone',139,'/federasyon','federation_bulletin'
where not exists(select 1 from public.faq_entries where feature='federation_bulletin' and active);
