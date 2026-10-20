set local lock_timeout = '15s';
insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Etkinlikleri telefonumun takvimine nasıl aktarırım?',
 'Takvimde gün ve filtreyi seç; gün başlığındaki takvime aktar simgesine bas. Görünen etkinlikler .ics dosyasına kaydedilir. Dosyayı telefonunun takvim uygulamasında açıp içe aktar. Sonraki değişiklikler veya iptaller otomatik eşitlenmez; SwanSport üzerinden kontrol et. Veliye özel sonuç ve raporlar dosyaya alınmaz. Dosyada görünen etkinlik başlığı ve konumu bulunur; paylaşırken bunu dikkate al.',
 'Takvim','everyone',211,'/calendar'
where not exists(select 1 from public.faq_entries where question='Etkinlikleri telefonumun takvimine nasıl aktarırım?');
