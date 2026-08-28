-- =============================================================================
-- SwanSport — Doğrulama belgeleri için Storage bucket + güvenlik kuralları
-- Supabase SQL editöründe BİR KEZ çalıştır (SETUP.sql + BOOTSTRAP.sql sonrası).
-- Tekrar çalıştırılabilir (idempotent).
-- =============================================================================

-- 1) Özel (public olmayan) bucket. Dosyalara yalnızca imzalı URL / yetkili
--    kullanıcı erişebilir.
insert into storage.buckets (id, name, public)
values ('verification-docs', 'verification-docs', false)
on conflict (id) do nothing;

-- 2) Erişim kuralları (storage.objects üzerinde RLS).
--    Yol düzeni: "{auth.uid}/{zaman}_{tip}.{uzantı}" — ilk klasör = sahibin id'si.

-- Yükleme: giriş yapan kullanıcı yalnızca KENDİ klasörüne yükleyebilir.
drop policy if exists "vdoc_upload_own" on storage.objects;
create policy "vdoc_upload_own" on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Okuma: dosyanın sahibi VEYA platform yöneticisi.
drop policy if exists "vdoc_read_own_or_admin" on storage.objects;
create policy "vdoc_read_own_or_admin" on storage.objects for select
  to authenticated
  using (
    bucket_id = 'verification-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_platform_admin()
    )
  );

-- Güncelleme (upsert için): yalnızca kendi klasörü.
drop policy if exists "vdoc_update_own" on storage.objects;
create policy "vdoc_update_own" on storage.objects for update
  to authenticated
  using (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'verification-docs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Silme: sahibi VEYA platform yöneticisi.
drop policy if exists "vdoc_delete_own_or_admin" on storage.objects;
create policy "vdoc_delete_own_or_admin" on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'verification-docs'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_platform_admin()
    )
  );
