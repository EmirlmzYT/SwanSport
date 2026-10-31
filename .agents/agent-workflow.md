# Agent Manager workflow

- Writer: görev türüne göre `flutter-ui`, `data-access` veya `database-security` ajanını seç; aynı dosyayı iki Writer'a verme.
- Reviewer: yazımdan sonra `swan-reviewer` veya ilgili uzman reviewer ile diff'i salt-okunur incelet.
- Agent Manager'ı aç, Workspace Agents altında ajanı seç, ardından yeni konuşmayı başlat.
- Aynı sohbetten ajan değiştirirsen Antigravity konuşmayı fork eder; sonucu yeni konuşmada takip et.
- Arka plan ajanlarının durumunu Agent Manager'dan izle; ayrıntı için satıra gir ve gerektiğinde çalışan ajanı durdur.
- Sıra: tek Writer → Reviewer → Writer hata düzeltmesi → doğrulama kanıtı.
