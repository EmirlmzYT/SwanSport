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

run_docker() {
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  elif sudo -n docker ps >/dev/null 2>&1; then
    sudo docker "$@"
  else
    sudo docker "$@"
  fi
}

# Otomatik Supabase PostgreSQL container tespiti
detect_db_container() {
  if [[ -n "$DB_CONTAINER" ]]; then
    echo "$DB_CONTAINER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    local found
    found="$(run_docker ps --format '{{.Names}}' 2>/dev/null | grep -E 'supabase[-_]db|postgres' | head -n 1 || true)"
    echo "$found"
  fi
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

  local cron_cmd="cd \"$REPO_DIR\" && WEB_ROOT=\"$target_web\" bash \"$REPO_DIR/tools/deploy_server.sh\" --cron >> \"$LOG_FILE\" 2>&1"
  local cron_entry="* * * * * $cron_cmd"

  (crontab -l 2>/dev/null | grep -v "tools/deploy_server.sh" || true; echo "$cron_entry") | crontab -
  echo "✅ Otomatik güncelleme kuruldu!"
  echo "   Artık GitHub'a her 'git push' yapıldığında sunucu 1 dakika içinde şifresiz olarak:"
  echo "   - Yeni kodu çeker ($REPO_DIR)"
  echo "   - swansport.com.tr vitrinini, favicon/logo ve SEO dosyalarını günceller ($target_web)"
  echo "   - Yeni SQL migration dosyalarını Supabase DB'ye uygular."
  echo "   Log dosyası: $LOG_FILE"
}

if [[ "${1:-}" == "--install-auto-pull" ]]; then
  install_auto_pull_cron
  exit 0
fi

cd "$REPO_DIR"
TARGET_WEB_ROOT="$(detect_web_root)"

# Cron modundaysa uzak repoda yeni commit varsa VEYA canlıdaki index.html/favicon repodakinden farklıysa çalış
if [[ "${1:-}" == "--cron" ]]; then
  git fetch origin "$BRANCH" --quiet
  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"
  HTML_SYNCED=true
  if [[ ! -f "$TARGET_WEB_ROOT/index.html" ]] || ! cmp -s "$REPO_DIR/landing/index.html" "$TARGET_WEB_ROOT/index.html" || [[ ! -f "$TARGET_WEB_ROOT/favicon.png" ]]; then
    HTML_SYNCED=false
  fi
  if [[ "$LOCAL_SHA" == "$REMOTE_SHA" && "$HTML_SYNCED" == "true" ]]; then
    exit 0
  fi
  echo "[$(date -Iseconds)] Güncelleme tetiklendi: $LOCAL_SHA -> $REMOTE_SHA (html_synced=$HTML_SYNCED)"
fi

echo "🦢 [1/3] Git üzerinden güncel kod çekiliyor ($BRANCH)..."
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "🦢 [2/3] swansport.com.tr vitrin, favicon, logo ve SEO dosyaları güncelleniyor -> $TARGET_WEB_ROOT"
copy_to_web_root "$REPO_DIR/landing/index.html" "$TARGET_WEB_ROOT/index.html"

if [[ -f "$REPO_DIR/landing/robots.txt" ]]; then
  copy_to_web_root "$REPO_DIR/landing/robots.txt" "$TARGET_WEB_ROOT/robots.txt"
fi
if [[ -f "$REPO_DIR/landing/sitemap.xml" ]]; then
  copy_to_web_root "$REPO_DIR/landing/sitemap.xml" "$TARGET_WEB_ROOT/sitemap.xml"
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

CONTAINER_NAME="$(detect_db_container)"
if [[ -n "$CONTAINER_NAME" ]]; then
  echo "🦢 [3/3] Supabase veritabanı migration kontrolü ($CONTAINER_NAME)..."
  for mig in \
    "$REPO_DIR/supabase/migrations/0119_turkey_sports_federations_catalog.sql" \
    "$REPO_DIR/supabase/migrations/0120_multi_branch_training_engine.sql" \
    "$REPO_DIR/supabase/migrations/0121_general_availability_and_club_training_sports.sql" \
    "$REPO_DIR/supabase/migrations/0122_launch_waitlist.sql"; do
    if [[ -f "$mig" ]]; then
      echo "   -> Uygulanıyor: $(basename "$mig")"
      run_docker exec -i "$CONTAINER_NAME" psql -v ON_ERROR_STOP=1 -U postgres -d postgres < "$mig" >/dev/null || true
    fi
  done
  echo "✅ Veritabanı migration'ları başarıyla uygulandı."
else
  echo "ℹ️  Aktif Supabase Docker container'ı bulunamadı, yalnız web dosyaları güncellendi."
fi

echo "🚀 Canlı güncelleme tamamlandı: $(git rev-parse --short HEAD)"
