-- =============================================================================
-- SwanSport — DÜZELTME: review_credential enum dönüşümü
--
-- Hata: column "status" is of type verification_status but expression is of
--       type text (42804)
--
-- Sebep: CASE ifadesi `text` üretiyor; PostgreSQL bunu enum'a kendiliğinden
--        çevirmiyor (düz 'approved' yazsaydık çevirirdi, CASE sonucu çevirmez).
-- Çözüm: sonucu açıkça verification_status'a dönüştür.
--
-- Supabase SQL editöründe çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================

create or replace function public.review_credential(
  p_cred uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_platform_admin() then raise exception 'Yetkisiz'; end if;
  update public.profile_credentials
     set status = (case when p_approve then 'approved' else 'rejected' end)
                  ::public.verification_status,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         note = p_note
   where id = p_cred;
end; $$;
