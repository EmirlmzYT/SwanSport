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
#      sudo bash tools/deploy_server.sh --install-auto-pull
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${DEPLOY_BRANCH:-main}"
WEB_ROOT="${WEB_ROOT:-}"
DB_CONTAINER="${DB_CONTAINER:-}"
LOG_FILE="${LOG_FILE:-/var/log/swansport-deploy.log}"

# Otomatik Web Root tespiti (/var/www/swansport.com.tr, /var/www/swansport, /var/www/html)
detect_web_root() {
  if [[ -n "$WEB_ROOT" ]]; then
    echo "$WEB_ROOT"
    return
  fi
  for candidate in \
    "/var/www/swansport.com.tr" \
    "/var/www/swansport" \
    "/usr/share/nginx/html" \
    "/var/www/html"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  echo "/var/www/swansport.com.tr"
}

# Otomatik Supabase PostgreSQL container tespiti
detect_db_container() {
  if [[ -n "$DB_CONTAINER" ]]; then
    echo "$DB_CONTAINER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    local found
    found="$(docker ps --format '{{.Names}}' | grep -E 'supabase[-_]db|postgres' | head -n 1 || true)"
    echo "$found"
  fi
}

install_auto_pull_cron() {
  local target_web
  target_web="$(detect_web_root)"
  local cron_cmd="cd \"$REPO_DIR\" && WEB_ROOT=\"$target_web\" bash \"$REPO_DIR/tools/deploy_server.sh\" --cron >> \"$LOG_FILE\" 2>&1"
  local cron_entry="* * * * * $cron_cmd"

  (crontab -l 2>/dev/null | grep -v "tools/deploy_server.sh" || true; echo "$cron_entry") | crontab -
  echo "✅ Otomatik güncelleme kuruldu!"
  echo "   Artık GitHub'a her 'git push' yapıldığında sunucu 1 dakika içinde:"
  echo "   - Yeni kodu çeker ($REPO_DIR)"
  echo "   - swansport.com.tr vitrinini günceller ($target_web)"
  echo "   - Yeni SQL migration dosyalarını Supabase DB'ye uygular."
  echo "   Log dosyası: $LOG_FILE"
}

if [[ "${1:-}" == "--install-auto-pull" ]]; then
  install_auto_pull_cron
  exit 0
fi

cd "$REPO_DIR"

# Cron modundaysa yalnızca uzak repoda yeni commit varsa çalış
if [[ "${1:-}" == "--cron" ]]; then
  git fetch origin "$BRANCH" --quiet
  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"
  if [[ "$LOCAL_SHA" == "$REMOTE_SHA" ]]; then
    exit 0
  fi
  echo "[$(date -Iseconds)] Yeni push algılandı: $LOCAL_SHA -> $REMOTE_SHA"
fi

echo "🦢 [1/3] Git üzerinden güncel kod çekiliyor ($BRANCH)..."
git fetch origin "$BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

TARGET_WEB_ROOT="$(detect_web_root)"
echo "🦢 [2/3] swansport.com.tr vitrin sayfası güncelleniyor -> $TARGET_WEB_ROOT"
mkdir -p "$TARGET_WEB_ROOT"
cp -f "$REPO_DIR/landing/index.html" "$TARGET_WEB_ROOT/index.html"

# Marka/logo asset'i varsa kopyala
if [[ -f "$REPO_DIR/assets/branding/official_swan_logo.jpg" ]]; then
  mkdir -p "$TARGET_WEB_ROOT/assets/branding"
  cp -f "$REPO_DIR/assets/branding/official_swan_logo.jpg" "$TARGET_WEB_ROOT/assets/branding/official_swan_logo.jpg"
fi

CONTAINER_NAME="$(detect_db_container)"
if [[ -n "$CONTAINER_NAME" ]]; then
  echo "🦢 [3/3] Supabase veritabanı migration kontrolü ($CONTAINER_NAME)..."
  # 0122_launch_waitlist.sql ve son migration'ları idempotent olarak uygula
  for mig in \
    "$REPO_DIR/supabase/migrations/0119_turkey_sports_federations_catalog.sql" \
    "$REPO_DIR/supabase/migrations/0120_multi_branch_training_engine.sql" \
    "$REPO_DIR/supabase/migrations/0121_general_availability_and_club_training_sports.sql" \
    "$REPO_DIR/supabase/migrations/0122_launch_waitlist.sql"; do
    if [[ -f "$mig" ]]; then
      echo "   -> Uygulanıyor: $(basename "$mig")"
      docker exec -i "$CONTAINER_NAME" psql -v ON_ERROR_STOP=1 -U postgres -d postgres < "$mig" >/dev/null
    fi
  done
  echo "✅ Veritabanı migration'ları başarıyla uygulandı."
else
  echo "ℹ️  Aktif Supabase Docker container'ı bulunamadı, yalnız web dosyaları güncellendi."
fi

echo "🚀 Canlı güncelleme tamamlandı: $(git rev-parse --short HEAD)"
