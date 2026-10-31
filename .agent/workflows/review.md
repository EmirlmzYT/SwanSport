# Diff İnceleme Akışı

- Uygulama yapan ajanla aynı varsayımları tekrar etme; diff'i sıfırdan oku.
- Önce `git diff --check` ve değişen dosya listesini incele.
- Her değişikliğin kullanıcı isteğine doğrudan bağlı olduğunu doğrula.
- Yanlış uygulama/paket, gereksiz dosya, refactor veya bağımlılık ekini işaretle.
- Uydurulmuş fonksiyon, provider, RPC, rota, model alanı veya paket API'si ara.
- Widget içinde Supabase çağrısı ve SwanAccess dışı yetki hesabı ara.
- SQL parametrelemesini, RLS'i, grants'i, input doğrulamasını ve çıktı kaçışını kontrol et.
- Derin bağlantı, manifest, `_redirects`, `/konsol/` base-href ve public davranışı korundu mu denetle.
- İlgili test/analiz çıktısını oku; çalıştırılmayan kontrolleri açıkça bildir.
- Sorun yoksa yalnız kanıtla desteklenen kısa onay ver; sorun varsa dosya ve satırı belirt.
