-- ---------------------------------------------------------------------------
-- 0074 — Antrenman motorundaki dört fonksiyonun izin temizliği
--
-- 0071 ve 0072'de RPC'lerin izinleri tek tek kaldırılmıştı ama **dört
-- fonksiyon atlandı**. Canlıda anon anahtarıyla yoklandığında üçü 200
-- dönüyordu:
--
--   valid_training_config    -> anon çağırabiliyordu
--   training_next_phase      -> anon çağırabiliyordu
--   training_phase_seconds   -> anon çağırabiliyordu
--   guard_training_protocol_immutable -> tetikleyici, doğrudan çağrılamaz
--
-- DÜRÜST OLALIM: bu bir veri sızıntısı DEĞİL. Üçü de saf fonksiyon; yalnızca
-- çağıranın kendi verdiği jsonb üzerinde hesap yapıyorlar, hiçbir tabloya
-- bakmıyorlar. Kapatılmalarının sebebi güvenlik açığı değil **kural**:
-- projede fonksiyon izinleri `PUBLIC`, `anon` ve `authenticated` için ayrı
-- ele alınıyor ve izin `PUBLIC`'ten miras alındığı için yalnızca `anon`'dan
-- almak yetmiyor. Bir istisna bırakmak, bir sonraki fonksiyonun da
-- atlanmasını normalleştiriyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) valid_training_config — `authenticated`'a GERİ VERİLİYOR
--
-- Bu fonksiyon `training_protocols` üzerindeki `training_protocol_config_valid`
-- check kısıtının gövdesinde. Kısıt ifadeleri ayrıştırılmış olarak saklandığı
-- için Postgres bunları INSERT anında yeniden yetki denetiminden geçirmiyor;
-- yani kuramsal olarak `authenticated` iznine gerek yok.
--
-- Yine de veriliyor: "gerek yok" kanısına dayanıp protokol yazmayı canlıda
-- kırma riskini almaya değmez. Platform yöneticisi `training_protocol_admin`
-- politikasıyla doğrudan `insert` yapabiliyor ve o yol `authenticated`
-- rolüyle çalışıyor. Maliyeti sıfır, kapattığı risk gerçek.
-- ---------------------------------------------------------------------------
revoke execute on function public.valid_training_config(jsonb) from public, anon;
grant  execute on function public.valid_training_config(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) Aşama makinesi — `authenticated`'a da VERİLMİYOR
--
-- Bu ikisini yalnızca `start_training_session`, `advance_session_phase` ve
-- `start_personal_session` çağırıyor. Üçü de `security definer`, yani
-- gövdelerinde sahibin (postgres) yetkisiyle çalışıyorlar ve çağıranın bu
-- fonksiyonlara ayrıca izni olması gerekmiyor.
--
-- İstemci tarafında da gerekmiyor: Dart'taki `nextPhase` önizlemeyi kendi
-- hesaplıyor (`swansport_branch_engine`), sunucuya sormuyor.
--
-- İleride istemci sunucuya sormak isterse buraya bir `grant` satırı eklenir;
-- şimdiden açık bırakmak "belki lazım olur" izni olurdu.
-- ---------------------------------------------------------------------------
revoke execute on function public.training_next_phase(text, int, jsonb)
  from public, anon, authenticated;
revoke execute on function public.training_phase_seconds(text, jsonb)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3) Tetikleyici fonksiyonu
--
-- `returns trigger` olduğu için PostgREST üzerinden zaten çağrılamıyor ve
-- Postgres doğrudan çağrılmasına izin vermiyor. İzin kaldırmak davranışı
-- değiştirmiyor; liste eksiksiz olsun diye burada. Tetikleyici, tabloya
-- bağlıyken sahibin yetkisiyle çalışmaya devam ediyor.
-- ---------------------------------------------------------------------------
revoke execute on function public.guard_training_protocol_immutable()
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4) Doğrulama
--
-- Çalıştırdıktan sonra anon anahtarıyla üçünün de 401 dönmesi gerekiyor.
-- 200 dönen kalırsa `PUBLIC` izni kaldırılmamış demektir.
--
-- Bu sorgu, motorun HİÇBİR fonksiyonunda `PUBLIC` izni kalmadığını gösterir;
-- boş küme dönmeli:
--
--   select p.proname, a.privilege_type, a.grantee
--     from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--     cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
--    where n.nspname = 'public'
--      and (p.proname like 'training_%' or p.proname like '%_training_%'
--           or p.proname in ('valid_training_config', 'is_athlete_self',
--                            'generate_join_code', 'session_summary',
--                            'session_overview', 'session_attendance_hint'))
--      and a.grantee = 0;   -- 0 = PUBLIC
-- ---------------------------------------------------------------------------
