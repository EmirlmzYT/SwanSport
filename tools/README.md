# Doğrulama araçları

Node 22, Python 3.13 ve Flutter 3.47.7 kullanılır. Kök dizinden:

```bash
npm ci --prefix tools --ignore-scripts --no-audit --no-fund
python -m venv .venv
# Windows: .venv\Scripts\python -m pip install -r tools/requirements-test.txt
.venv/bin/python -m pip install -r tools/requirements-test.txt
npm test --prefix tools
.venv/bin/python tools/check_migrations.py
.venv/bin/python tools/check_faq.py
python tools/check_push_routes.py
python tools/check_mobile_ui_tokens.py
python tools/mobile_release_acceptance.py
python -m unittest discover -s tools -p '*_test.py'
python tools/release_matrix.py --output build/release-matrix.json
```

Python ortamında pip yoksa `uv venv .venv` ve
`uv pip install --python .venv/bin/python -r tools/requirements-test.txt`
kullanılabilir. Bağımlılıklar build dizininden yüklenmez; npm lock sürümü
aynı kurulumu CI ve yerelde sağlar.

SQL testleri izole PGlite üzerinde çalışır; production URL veya anahtar
istemez. Fixture modüllerinin import ettiği testler tek süreçte bir kez
kaydedilir (`--experimental-test-isolation=none`); testler sırayla çalışır,
HTTP mock'ları eşzamanlı paylaşılmaz. Bu, gerçek GoTrue/PostgREST, pg_net
worker, pg_cron veya çok bağlantılı yarış kanıtı değildir.

Flutter regresyonu her uygulama/paketin kendi dizininde `flutter test --no-pub`
ile çalışır; kökten yol vermek asset/yerel dosya sözleşmesini bozar.
CI yedi hedefin tamamını ve iki production web entrypoint'inin
derlemesini kapsar. Android, iOS ve konsol artifact işleri aynı commit'in
bu kontrollerini bekler. Genel format borcu yalnız raporlanır; test ve
analyzer hata/uyarıları engelleyicidir. Ana Sayfa görsel kaynakları bu
güvenilirlik paketinde değiştirilmez.
