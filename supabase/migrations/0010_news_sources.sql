-- =============================================================================
-- SwanSport — HABER KAYNAKLARI (RSS)
--
-- Platform yöneticisi panelden kaynak ekler/kaldırır; akışta herkese görünür.
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================

create table if not exists public.rss_sources (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  url        text not null,
  active     boolean not null default true,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null
);

create unique index if not exists idx_rss_url on public.rss_sources (url);

alter table public.rss_sources enable row level security;

-- Herkes aktif kaynakları görebilir (akışta haber gösterebilmek için).
drop policy if exists "rss_read" on public.rss_sources;
create policy "rss_read" on public.rss_sources for select
  to authenticated using (true);

-- Yalnızca platform yöneticisi ekler/düzenler/siler.
drop policy if exists "rss_admin_write" on public.rss_sources;
create policy "rss_admin_write" on public.rss_sources for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Başlangıç kaynakları — canlı olarak test edilip çalıştığı doğrulandı.
-- Panelden istediğini kapatabilir, yenisini ekleyebilirsin.
insert into public.rss_sources (name, url)
values
  ('AA Spor',      'https://www.aa.com.tr/tr/rss/default?cat=spor'),
  ('Hürriyet Spor','https://www.hurriyet.com.tr/rss/spor')
on conflict (url) do nothing;
