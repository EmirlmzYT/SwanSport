-- =============================================================================
-- 0123: Profil Sosyal Medya, İletişim ve Sporcu Özellikleri
--
-- Kullanıcıların profillerine isteğe bağlı Instagram, Twitter/X, Website
-- ve telefon numarası ekleyebilmesini sağlar.
-- Telefon numarasının profilde herkese açık mı yoksa gizli mi kalacağı
-- `phone_hidden` bayrağıyla kontrol edilir (varsayılan: true / gizli).
-- Ayrıca birincil branş, mevki, boy, kilo ve baskın el/ayak alanlarını içerir.
-- =============================================================================

alter table public.profiles
  add column if not exists instagram     text,
  add column if not exists twitter       text,
  add column if not exists website       text,
  add column if not exists phone_hidden  boolean not null default true,
  add column if not exists primary_sport text,
  add column if not exists position      text,
  add column if not exists height_cm     int,
  add column if not exists weight_kg     numeric(5,1),
  add column if not exists dominant_side text;

comment on column public.profiles.phone_hidden is
  'Telefon numarasının diğer kullanıcılara açık olup olmadığı (varsayılan: true/gizli).';
