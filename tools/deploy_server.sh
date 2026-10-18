#!/usr/bin/env bash
# ==============================================================================
# SwanSport — Kendi Sunucumuz İçin Otomatik Güncelleme & Deploy Scripti
# ==============================================================================
# Kullanım:
#   1) Manuel tek sefer çalıştırma:
#      bash tools/deploy_server.sh
#
#   2) Her "git push" sonrası sunucunun otomatik güncellenmesini kurmak için
#      (Sunucuda sadece 1 kez çalıştırman yeterli):
#      bash tools/deploy_server.sh --install-auto-pull
# ==============================================================================

set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${DEPLOY_BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-}"
DB_CONTAINER="${DB_CONTAINER:-}"
LOG_FILE="${LOG_FILE:-$HOME/swansport-deploy.log}"

# Otomatik Web Root tespiti (aaPanel /www/wwwroot/swansport.com.tr, /var/www/...)
detect_web_root() {
  if [[ -n "$WEB_ROOT" ]]; then
    echo "$WEB_ROOT"
    return
  fi
  for candidate in \
    "/www/wwwroot/swansport.com.tr" \
    "/var/www/swansport.com.tr" \
    "/var/www/swansport" \
    "/usr/share/nginx/html" \
    "/var/www/html"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  echo "/www/wwwroot/swansport.com.tr"
}

# Otomatik Konsol Web Root tespiti (aaPanel /www/wwwroot/konsol.swansport.com.tr, /var/www/...)
detect_console_root() {
  if [[ -n "${CONSOLE_WEB_ROOT:-}" ]]; then
    echo "$CONSOLE_WEB_ROOT"
    return
  fi
  for candidate in \
    "/www/wwwroot/konsol.swansport.com.tr" \
    "/var/www/konsol.swansport.com.tr" \
    "/www/wwwroot/console.swansport.com.tr"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  echo ""
}

CONSOLE_RELEASE_URL="https://github.com/EmirlmzYT/SwanSport/releases/download/v0.5.2+20/swansport-console-web.zip"

fetch_console_release_sig() {
  if command -v curl >/dev/null 2>&1; then
    curl -sIL --max-time 10 "$CONSOLE_RELEASE_URL" 2>/dev/null \
      | tr -d '\r' \
      | awk 'tolower($1) == "etag:" || tolower($1) == "last-modified:" || tolower($1) == "content-length:" {print tolower($1), $2, $3, $4, $5}' \
      | tail -n 3 \
      | tr '\n' '|' || true
  fi
}

sync_console_web_if_needed() {
  local console_dir
  console_dir="$(detect_console_root)"
  if [[ -z "$console_dir" || ! -d "$console_dir" ]]; then
    return 0
  fi
  local remote_sig
  remote_sig="$(fetch_console_release_sig)"
  if [[ -z "$remote_sig" ]]; then
    return 0
  fi
  local local_sig=""
  if [[ -f "$console_dir/.console_release_sig" ]]; then
    local_sig="$(cat "$console_dir/.console_release_sig" 2>/dev/null || true)"
  fi
  if [[ "$remote_sig" == "$local_sig" && -f "$console_dir/main.dart.js" ]]; then
    return 0
  fi
  echo "🦢 Konsol web paketi güncelleniyor -> $console_dir"
  local tmp_zip="/tmp/swansport-console-web-$$.zip"
  local tmp_extract="/tmp/swansport-console-extract-$$"
  if curl -fsSL --max-time 60 "$CONSOLE_RELEASE_URL" -o "$tmp_zip"; then
    rm -rf "$tmp_extract"
    mkdir -p "$tmp_extract"
    if command -v unzip >/dev/null 2>&1 && unzip -oq "$tmp_zip" -d "$tmp_extract"; then
      if cp -rf "$tmp_extract"/. "$console_dir"/ 2>/dev/null; then
        echo -n "$remote_sig" > "$console_dir/.console_release_sig" 2>/dev/null || true
      else
        ensure_web_root_writable "$console_dir"
        cp -rf "$tmp_extract"/. "$console_dir"/ 2>/dev/null || sudo cp -rf "$tmp_extract"/. "$console_dir"/
        echo -n "$remote_sig" | sudo tee "$console_dir/.console_release_sig" >/dev/null || true
      fi
      echo "✅ konsol.swansport.com.tr başarıyla güncellendi."
    elif command -v python3 >/dev/null 2>&1; then
      python3 -m zipfile -e "$tmp_zip" "$tmp_extract"
      if cp -rf "$tmp_extract"/. "$console_dir"/ 2>/dev/null; then
        echo -n "$remote_sig" > "$console_dir/.console_release_sig" 2>/dev/null || true
      else
        ensure_web_root_writable "$console_dir"
        cp -rf "$tmp_extract"/. "$console_dir"/ 2>/dev/null || sudo cp -rf "$tmp_extract"/. "$console_dir"/
        echo -n "$remote_sig" | sudo tee "$console_dir/.console_release_sig" >/dev/null || true
      fi
      echo "✅ konsol.swansport.com.tr başarıyla güncellendi (python3 zipfile)."
    fi
  fi
  rm -rf "$tmp_zip" "$tmp_extract"
}

run_docker() {
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  elif sudo -n docker ps >/dev/null 2>&1; then
    sudo docker "$@"
  else
    sudo docker "$@"
  fi
}

# Otomatik Supabase PostgreSQL container tespiti (hem image hem isim üzerinden)
detect_db_container() {
  if [[ -n "$DB_CONTAINER" ]]; then
    echo "$DB_CONTAINER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    local found
    found="$(run_docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk '$2 ~ /postgres/ || $1 ~ /supabase[-_]db/ {print $1; exit}')"
    echo "$found"
  fi
}

run_psql_file() {
  local container="$1"
  local file="$2"
  run_docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U postgres -d postgres < "$file" >/dev/null 2>&1 \
    || run_docker exec -i "$container" psql -v ON_ERROR_STOP=1 -U supabase_admin -d postgres < "$file" >/dev/null 2>&1 \
    || run_docker exec -i -e PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" "$container" psql -h 127.0.0.1 -v ON_ERROR_STOP=1 -U postgres -d postgres < "$file" >/dev/null 2>&1 \
    || true
}

ensure_web_root_writable() {
  local target_web="$1"
  local current_user
  current_user="$(id -un)"
  if [[ ! -w "$target_web" ]] || [[ -f "$target_web/index.html" && ! -w "$target_web/index.html" ]]; then
    sudo mkdir -p "$target_web"
    sudo chown -R "${current_user}" "$target_web" 2>/dev/null || sudo chmod -R a+rwX "$target_web"
  fi
}

copy_to_web_root() {
  local src="$1"
  local dst="$2"
  local dst_dir
  dst_dir="$(dirname "$dst")"
  if mkdir -p "$dst_dir" 2>/dev/null && cp -f "$src" "$dst" 2>/dev/null; then
    return 0
  else
    ensure_web_root_writable "$dst_dir"
    mkdir -p "$dst_dir" 2>/dev/null || sudo mkdir -p "$dst_dir"
    cp -f "$src" "$dst" 2>/dev/null || sudo cp -f "$src" "$dst"
  fi
}

install_auto_pull_cron() {
  local target_web
  target_web="$(detect_web_root)"
  echo "🔑 Web klasörü ($target_web) için arka plan yazma izni tanımlanıyor..."
  ensure_web_root_writable "$target_web"
  local console_web
  console_web="$(detect_console_root)"
  if [[ -n "$console_web" && -d "$console_web" ]]; then
    ensure_web_root_writable "$console_web"
  fi

  local cron_cmd="cd \"$REPO_DIR\" && WEB_ROOT=\"$target_web\" bash \"$REPO_DIR/tools/deploy_server.sh\" --cron >> \"$LOG_FILE\" 2>&1"
  local cron_entry="* * * * * $cron_cmd"

  (crontab -l 2>/dev/null | grep -v "tools/deploy_server.sh" || true; echo "$cron_entry") | crontab -
  echo "✅ Otomatik güncelleme kuruldu!"
  echo "   Artık GitHub'a her 'git push' yapıldığında sunucu 1 dakika içinde şifresiz olarak:"
  echo "   - Yeni kodu çeker ($REPO_DIR)"
  echo "   - swansport.com.tr vitrinini, favicon/logo ve SEO dosyalarını günceller ($target_web)"
  echo "   - konsol.swansport.com.tr yeni derlemesini otomatik indirip açar"
  echo "   - Yeni SQL migration dosyalarını Supabase DB'ye uygular."
  echo "   Log dosyası: $LOG_FILE"
}

if [[ "${1:-}" == "--install-auto-pull" ]]; then
  install_auto_pull_cron
  exit 0
fi

cd "$REPO_DIR"
TARGET_WEB_ROOT="$(detect_web_root)"

# Cron modundaysa uzak repoda yeni commit varsa VEYA canlıdaki dosyalar/DB/Konsol henüz senkron değilse çalış
if [[ "${1:-}" == "--cron" ]]; then
  git fetch origin "$BRANCH" --quiet
  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"
  HTML_SYNCED=true
  if [[ ! -f "$TARGET_WEB_ROOT/index.html" ]] || ! cmp -s "$REPO_DIR/landing/index.html" "$TARGET_WEB_ROOT/index.html" || [[ ! -f "$TARGET_WEB_ROOT/favicon.png" ]] || ! cmp -s "$REPO_DIR/landing/llms.txt" "$TARGET_WEB_ROOT/llms.txt"; then
    HTML_SYNCED=false
  fi
  DB_CHECK_CONTAINER="$(detect_db_container)"
  if [[ -n "$DB_CHECK_CONTAINER" ]]; then
    HAS_WAITLIST="$(run_docker exec -i "$DB_CHECK_CONTAINER" psql -U postgres -d postgres -tAc "select to_regclass('public.launch_waitlist');" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$HAS_WAITLIST" != "public.launch_waitlist" && "$HAS_WAITLIST" != "launch_waitlist" ]]; then
      HTML_SYNCED=false
    fi
  fi
  CONSOLE_CHECK_DIR="$(detect_console_root)"
  if [[ -n "$CONSOLE_CHECK_DIR" && -d "$CONSOLE_CHECK_DIR" ]]; then
    REMOTE_CONSOLE_SIG="$(fetch_console_release_sig)"
    LOCAL_CONSOLE_SIG="$(cat "$CONSOLE_CHECK_DIR/.console_release_sig" 2>/dev/null || true)"
    if [[ -n "$REMOTE_CONSOLE_SIG" && "$REMOTE_CONSOLE_SIG" != "$LOCAL_CONSOLE_SIG" ]]; then
      HTML_SYNCED=false
    fi
  fi
  if [[ "$LOCAL_SHA" == "$REMOTE_SHA" && "$HTML_SYNCED" == "true" ]]; then
    exit 0
  fi
  echo "[$(date -Iseconds)] Güncelleme tetiklendi: $LOCAL_SHA -> $REMOTE_SHA (synced=$HTML_SYNCED)"
fi

if [[ "${1:-}" != "--post-pull" ]]; then
  echo "🦢 [1/3] Git üzerinden güncel kod çekiliyor ($BRANCH)..."
  git fetch origin "$BRANCH"
  git checkout "$BRANCH"
  git pull --ff-only origin "$BRANCH"
  exec bash "$REPO_DIR/tools/deploy_server.sh" --post-pull
fi

echo "🦢 [2/3] swansport.com.tr vitrin, favicon, logo ve SEO dosyaları güncelleniyor -> $TARGET_WEB_ROOT"
copy_to_web_root "$REPO_DIR/landing/index.html" "$TARGET_WEB_ROOT/index.html"

if [[ -f "$REPO_DIR/landing/robots.txt" ]]; then
  copy_to_web_root "$REPO_DIR/landing/robots.txt" "$TARGET_WEB_ROOT/robots.txt"
fi
if [[ -f "$REPO_DIR/landing/sitemap.xml" ]]; then
  copy_to_web_root "$REPO_DIR/landing/sitemap.xml" "$TARGET_WEB_ROOT/sitemap.xml"
fi
if [[ -f "$REPO_DIR/landing/llms.txt" ]]; then
  copy_to_web_root "$REPO_DIR/landing/llms.txt" "$TARGET_WEB_ROOT/llms.txt"
fi

# Konsol ile birebir aynı favicon ve uygulama ikonları
if [[ -f "$REPO_DIR/apps/swansport_console/web/favicon.png" ]]; then
  copy_to_web_root "$REPO_DIR/apps/swansport_console/web/favicon.png" "$TARGET_WEB_ROOT/favicon.png"
fi
if [[ -f "$REPO_DIR/apps/swansport_console/web/icons/Icon-192.png" ]]; then
  copy_to_web_root "$REPO_DIR/apps/swansport_console/web/icons/Icon-192.png" "$TARGET_WEB_ROOT/icons/Icon-192.png"
fi
if [[ -f "$REPO_DIR/apps/swansport_console/web/icons/Icon-512.png" ]]; then
  copy_to_web_root "$REPO_DIR/apps/swansport_console/web/icons/Icon-512.png" "$TARGET_WEB_ROOT/icons/Icon-512.png"
fi

# Resmi kuğu marka logosu
if [[ -f "$REPO_DIR/assets/branding/official_swan_logo.jpg" ]]; then
  copy_to_web_root "$REPO_DIR/assets/branding/official_swan_logo.jpg" "$TARGET_WEB_ROOT/assets/branding/official_swan_logo.jpg"
fi

# konsol.swansport.com.tr yeni derleme varsa indir ve aç
sync_console_web_if_needed

CONTAINER_NAME="$(detect_db_container)"
if [[ -n "$CONTAINER_NAME" ]]; then
  echo "🦢 [3/3] Supabase veritabanı migration kontrolü ($CONTAINER_NAME)..."
  for mig in \
    "$REPO_DIR/supabase/migrations/0122_launch_waitlist.sql" \
    "$REPO_DIR/supabase/migrations/0119_turkey_sports_federations_catalog.sql" \
    "$REPO_DIR/supabase/migrations/0120_multi_branch_training_engine.sql" \
    "$REPO_DIR/supabase/migrations/0121_general_availability_and_club_training_sports.sql"; do
    if [[ -f "$mig" ]]; then
      echo "   -> Uygulanıyor: $(basename "$mig")"
      run_psql_file "$CONTAINER_NAME" "$mig"
    fi
  done
  echo "✅ Veritabanı migration'ları başarıyla uygulandı."
else
  echo "ℹ️  Aktif Supabase Docker container'ı bulunamadı, yalnız web dosyaları güncellendi."
fi

echo "🚀 Canlı güncelleme tamamlandı: $(git rev-parse --short HEAD)"
