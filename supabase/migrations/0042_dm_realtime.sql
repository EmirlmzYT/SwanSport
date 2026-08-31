-- 0042 — Doğrudan mesajlar canlı aksın
--
-- SORUN: DM'ler canlı güncellenmiyordu. Sebep uygulama tarafında değil
-- burada: `direct_messages` **`supabase_realtime` publication'ında yok**.
-- 0016 yalnızca `community_messages`'ı eklemiş; topluluk sohbeti canlı
-- çalışırken DM'in çalışmamasının tek sebebi bu satırın eksikliğiydi.
--
-- Publication'a eklenmeden istemci tarafında `.stream()` yazmak işe
-- yaramaz: abonelik kurulur, hata da vermez, ama hiçbir olay gelmez.
-- Sessizce çalışmayan bu tür şeyler en pahalı olanlar.

-- `replica identity full` UPDATE ve DELETE olaylarının **eski satırı** da
-- taşıması için gerekli. DM'de bu okundu bilgisi demek: `read_at`
-- güncellendiğinde karşı tarafın ekranındaki tek tik çift tike dönebilsin.
-- Yalnızca INSERT yeterli olsaydı buna gerek yoktu.
alter table public.direct_messages replica identity full;

do $$
begin
  alter publication supabase_realtime add table public.direct_messages;
exception
  when duplicate_object then null;   -- zaten eklenmiş
  when undefined_object then null;   -- publication yoksa sessizce geç
end $$;

-- RLS zaten doğru: `dm_read_own` yalnızca gönderen ya da alan olduğun
-- satırları veriyor (0009). Realtime bu politikaya uyduğu için filtresiz
-- abone olmak bile başkasının mesajını taşımıyor — istemci tarafında
-- ayrıca güvenlik kontrolü gerekmiyor.

-- ---------------------------------------------------------------------------
-- Sohbetteyken gelen mesajı okundu işaretlemek için: tek mesaj hedefli.
--
-- `mark_conversation_read` bütün sohbeti işaretliyor ve ekrandayken her yeni
-- mesajda onu çağırmak tüm konuşmayı baştan yazmak demek. Bu yalnızca
-- okunmamış olanlara dokunuyor.
-- ---------------------------------------------------------------------------
create or replace function public.mark_messages_read(p_ids uuid[])
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_count int;
begin
  update public.direct_messages
     set read_at = now()
   where id = any(p_ids)
     -- Yalnızca BANA gelenler. Kendi gönderdiğimi okundu işaretleyemem;
     -- aksi hâlde gönderen tarafın ekranında sahte çift tik çıkardı.
     and recipient_id = auth.uid()
     and read_at is null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$fn$;

revoke execute on function public.mark_messages_read(uuid[]) from public, anon;
grant execute on function public.mark_messages_read(uuid[]) to authenticated;
