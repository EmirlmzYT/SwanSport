-- Display preferences stay on the device. This migration adds help only.
begin;
set local lock_timeout = '15s';

insert into public.faq_entries
  (question, answer, category, audience, route, sort_order)
select
  'Ana sayfadaki hızlı erişim kısayollarını nasıl düzenlerim?',
  'Ana sayfada Hızlı erişim yanındaki Düzenle düğmesini veya Ayarlar → Ana sayfa → Hızlı erişim yolunu kullan. En fazla dört kısayol seçebilir, kaldırabilir, sürükleyerek veya yukarı oklarıyla sıralayabilirsin. Ana sayfada göster seçeneği alanı gizler; seçimlerin saklanır. Kaydet değişiklikleri uygular. Varsayılana dön, görevlerine uygun başlangıç düzenini seçer. Tercihler bu cihazda hesabına özel saklanır, diğer cihazlara eşitlenmez. Yetkin veya bir özelliğin kullanılabilirliği değişirse ilgili kısayol gizlenir; kısayol seçmek yeni yetki vermez.',
  'Hesap', 'everyone', '/settings', 160
where not exists (
  select 1 from public.faq_entries
  where question = 'Ana sayfadaki hızlı erişim kısayollarını nasıl düzenlerim?'
);

commit;
