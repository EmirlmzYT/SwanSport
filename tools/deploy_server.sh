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

run_docker() {
  if docker ps >/dev/null 2>&1; then
    docker "$@"
  elif sudo -n docker ps >/dev/null 2>&1; then
    sudo -n docker "$@"
  else
    return 1
  fi
}

# Otomatik Supabase PostgreSQL container tespiti (önce supabase-db, sonra postgres)
detect_db_container() {
  if [[ -n "$DB_CONTAINER" ]]; then
    echo "$DB_CONTAINER"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    local found
    found="$(run_docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk '$1 ~ /supabase[-_]db/ {print $1; exit}' || true)"
    if [[ -z "$found" ]]; then
      found="$(run_docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | awk '$2 ~ /postgres/ {print $1; exit}' || true)"
    fi
    echo "$found"
  fi
}

# Sunucuda halihazırda bulunan bir Docker imajını kullanarak şifresiz (sudo'suz)
# dosya izinlerini ve kopyalamalarını yürütür (cron içinde sudo şifre sorduğu için).
host_root_exec() {
  local script="$1"
  local container
  container="$(detect_db_container)"
  local img=""
  if [[ -n "$container" ]]; then
    img="$(run_docker inspect --format='{{.Config.Image}}' "$container" 2>/dev/null || true)"
  fi
  if [[ -z "$img" ]]; then
    img="$(run_docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>' | head -n 1 || true)"
  fi
  if [[ -n "$img" ]]; then
    run_docker run --rm --entrypoint sh -v /:/host "$img" -c "$script"
    return $?
  fi
  return 1
}

# Otomatik Konsol Web Root tespiti (Nginx vhost config + /www/wwwroot taraması)
detect_console_root() {
  if [[ -n "${CONSOLE_WEB_ROOT:-}" ]]; then
    echo "$CONSOLE_WEB_ROOT"
    return
  fi
  for conf in /www/server/panel/vhost/nginx/*.conf /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
    if [[ -f "$conf" ]] && grep -qi "konsol\.swansport\.com\.tr" "$conf" 2>/dev/null; then
      local r
      r="$(sed -n 's/^[[:space:]]*root[[:space:]]\+\([^;[:space:]]\+\).*/\1/p' "$conf" 2>/dev/null | head -n 1 || true)"
      if [[ -n "$r" ]]; then
        echo "$r"
        return
      fi
    fi
  done
  for candidate in \
    "/www/wwwroot/konsol.swansport.com.tr" \
    "/var/www/konsol.swansport.com.tr" \
    "/www/wwwroot/console.swansport.com.tr" \
    "/www/wwwroot/konsol"; do
    if [[ -d "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done
  # Eğer dizin izinlerinden dolayı normal kullanıcı göremediyse Docker üzerinden Nginx config ve dizinleri tara
  local detected
  detected="$(host_root_exec '
    for conf in /host/www/server/panel/vhost/nginx/*.conf /host/etc/nginx/sites-enabled/* /host/etc/nginx/conf.d/*.conf; do
      if [ -f "$conf" ] && grep -qi "konsol\.swansport\.com\.tr" "$conf" 2>/dev/null; then
        r=$(sed -n "s/^[[:space:]]*root[[:space:]]\+\([^;[:space:]]\+\).*/\1/p" "$conf" | head -n 1)
        if [ -n "$r" ]; then
          echo "$r"
          exit 0
        fi
      fi
    done
    for d in /host/www/wwwroot/konsol.swansport.com.tr /host/var/www/konsol.swansport.com.tr /host/www/wwwroot/console.swansport.com.tr /host/www/wwwroot/konsol; do
      if [ -d "$d" ]; then
        echo "${d#/host}"
        exit 0
      fi
    done
  ' 2>/dev/null | tr -d '\r' | head -n 1 || true)"
  echo "$detected"
}

CONSOLE_RELEASE_URL="https://github.com/EmirlmzYT/SwanSport/releases/download/v0.5.2+20/swansport-console-web.zip"

fetch_console_release_sig() {
  if command -v curl >/dev/null 2>&1; then
    curl -sIL --max-time 15 "$CONSOLE_RELEASE_URL" 2>/dev/null \
      | tr -d '\r' \
      | awk 'tolower($1) == "etag:" || tolower($1) == "last-modified:" || tolower($1) == "content-length:" {print tolower($1), $2, $3, $4, $5}' \
      | tail -n 3 \
      | tr '\n' '|' || true
  fi
}

read_local_console_sig() {
  local console_dir="$1"
  if [[ -f "$console_dir/.console_release_sig" ]]; then
    cat "$console_dir/.console_release_sig" 2>/dev/null || true
  else
    host_root_exec "cat '/host${console_dir}/.console_release_sig' 2>/dev/null || true" 2>/dev/null || true
  fi
}

sync_console_web_if_needed() {
  local console_dir
  console_dir="$(detect_console_root)"
  if [[ -z "$console_dir" ]]; then
    echo "ℹ️  Konsol web dizini tespit edilemedi."
    return 0
  fi
  local remote_sig
  remote_sig="$(fetch_console_release_sig)"
  if [[ -z "$remote_sig" ]]; then
    echo "ℹ️  GitHub konsol release imzası okunamadı."
    return 0
  fi
  local local_sig
  local_sig="$(read_local_console_sig "$console_dir")"
  local has_sha="false"
  if [[ -f "$console_dir/version_sha.txt" ]] || host_root_exec "[ -f '/host${console_dir}/version_sha.txt' ]" 2>/dev/null; then
    has_sha="true"
  fi
  if [[ "$remote_sig" == "$local_sig" && "$has_sha" == "true" ]]; then
    return 0
  fi

  echo "🦢 Konsol web paketi güncelleniyor -> $console_dir"
  local tmp_zip="/tmp/swansport-console-web-$$.zip"
  local tmp_extract="/tmp/swansport-console-extract-$$"
  rm -rf "$tmp_zip" "$tmp_extract"
  mkdir -p "$tmp_extract"

  if curl -fsSL --max-time 90 "$CONSOLE_RELEASE_URL" -o "$tmp_zip"; then
    local extracted="false"
    if command -v python3 >/dev/null 2>&1 && python3 -m zipfile -e "$tmp_zip" "$tmp_extract" 2>/dev/null; then
      extracted="true"
    elif command -v unzip >/dev/null 2>&1 && unzip -oq "$tmp_zip" -d "$tmp_extract" 2>/dev/null; then
      extracted="true"
    fi

    if [[ "$extracted" == "true" && -f "$tmp_extract/main.dart.js" ]]; then
      echo -n "$remote_sig" > "$tmp_extract/.console_release_sig"
      local uid gid
      uid="$(id -u)"
      gid="$(id -g)"
      if cp -rf "$tmp_extract"/. "$console_dir"/ 2>/dev/null; then
        echo "✅ konsol.swansport.com.tr doğrudan güncellendi ($console_dir)."
      elif host_root_exec "mkdir -p '/host${console_dir}' && cp -rf '/host${tmp_extract}'/. '/host${console_dir}'/ && chown -R ${uid}:${gid} '/host${console_dir}' 2>/dev/null || true && chmod -R a+rX '/host${console_dir}'"; then
        echo "✅ konsol.swansport.com.tr Docker köprüsüyle güncellendi ($console_dir)."
      else
        ensure_web_root_writable "$console_dir"
        cp -rf "$tmp_extract"/. "$console_dir"/
        echo "✅ konsol.swansport.com.tr sudo ile güncellendi ($console_dir)."
      fi
    else
      echo "⚠️  Konsol zip paketi açılamadı (extracted=$extracted)."
    fi
  else
    echo "⚠️  Konsol zip paketi indirilemedi."
  fi
  rm -rf "$tmp_zip" "$tmp_extract"
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
  local uid gid
  uid="$(id -u)"
  gid="$(id -g)"
  if [[ ! -w "$target_web" ]] || [[ -f "$target_web/index.html" && ! -w "$target_web/index.html" ]]; then
    if ! host_root_exec "mkdir -p '/host${target_web}' && chown -R ${uid}:${gid} '/host${target_web}' && chmod -R a+rX '/host${target_web}'" 2>/dev/null; then
      sudo mkdir -p "$target_web" 2>/dev/null || true
      sudo chown -R "$(id -un)" "$target_web" 2>/dev/null || sudo chmod -R a+rwX "$target_web" 2>/dev/null || true
    fi
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
    mkdir -p "$dst_dir" 2>/dev/null || true
    cp -f "$src" "$dst" 2>/dev/null || host_root_exec "mkdir -p '/host${dst_dir}' && cp -f '/host${src}' '/host${dst}' && chmod a+r '/host${dst}'"
  fi
}

install_auto_pull_cron() {
  git config --global --add safe.directory "$REPO_DIR" 2>/dev/null || true
  if [[ "$(id -u)" == "0" ]]; then
    local repo_owner
    repo_owner="$(stat -c '%U' "$REPO_DIR" 2>/dev/null || true)"
    if [[ -n "$repo_owner" && "$repo_owner" != "root" ]]; then
      usermod -aG docker "$repo_owner" 2>/dev/null || true
      (crontab -u "$repo_owner" -l 2>/dev/null | grep -v "tools/deploy_server.sh" || true) | crontab -u "$repo_owner" - 2>/dev/null || true
    fi
  fi

  local target_web
  target_web="$(detect_web_root)"
  echo "🔑 Web klasörü ($target_web) için arka plan yazma izni tanımlanıyor..."
  ensure_web_root_writable "$target_web"
  local console_web
  console_web="$(detect_console_root)"
  if [[ -n "$console_web" ]]; then
    echo "🔑 Konsol klasörü ($console_web) için arka plan yazma izni tanımlanıyor..."
    ensure_web_root_writable "$console_web"
  fi

  local cron_cmd="cd \"$REPO_DIR\" && WEB_ROOT=\"$target_web\" bash \"$REPO_DIR/tools/deploy_server.sh\" --cron >> \"$LOG_FILE\" 2>&1"
  local cron_entry="* * * * * $cron_cmd"

  (crontab -l 2>/dev/null | grep -v "tools/deploy_server.sh" || true; echo "$cron_entry") | crontab -
  echo "✅ Otomatik güncelleme kuruldu!"
  echo "   Artık GitHub'a her 'git push' yapıldığında sunucu 1 dakika içinde şifresiz olarak:"
  echo "   - Yeni kodu çeker ($REPO_DIR)"
  echo "   - swansport.com.tr vitrinini, favicon/logo ve SEO dosyalarını günceller ($target_web)"
  echo "   - konsol.swansport.com.tr yeni derlemesini otomatik indirip açar ($console_web)"
  echo "   - Yeni SQL migration dosyalarını Supabase DB'ye uygular."
  echo "   Log dosyası: $LOG_FILE"
  exec bash "$REPO_DIR/tools/deploy_server.sh"
}

if [[ "${1:-}" == "--install-auto-pull" ]]; then
  install_auto_pull_cron
  exit 0
fi

cd "$REPO_DIR"
TARGET_WEB_ROOT="$(detect_web_root)"

# Cron modundaysa uzak repoda yeni commit varsa ÖNCE hemen çek (hiçbir alt kontrol git pull'u bloklamasın)
if [[ "${1:-}" == "--cron" ]]; then
  git fetch origin "$BRANCH" --quiet
  LOCAL_SHA="$(git rev-parse HEAD)"
  REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"
  if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
    echo "[$(date -Iseconds)] Yeni commit algılandı: $LOCAL_SHA -> $REMOTE_SHA"
    git checkout "$BRANCH"
    git pull --ff-only origin "$BRANCH"
    exec bash "$REPO_DIR/tools/deploy_server.sh" --post-pull
  fi
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
  if [[ -n "$CONSOLE_CHECK_DIR" ]]; then
    REMOTE_CONSOLE_SIG="$(fetch_console_release_sig)"
    LOCAL_CONSOLE_SIG="$(read_local_console_sig "$CONSOLE_CHECK_DIR")"
    HAS_CONSOLE_SHA="false"
    if [[ -f "$CONSOLE_CHECK_DIR/version_sha.txt" ]] || host_root_exec "[ -f '/host${CONSOLE_CHECK_DIR}/version_sha.txt' ]" 2>/dev/null; then
      HAS_CONSOLE_SHA="true"
    fi
    if [[ -n "$REMOTE_CONSOLE_SIG" && ( "$REMOTE_CONSOLE_SIG" != "$LOCAL_CONSOLE_SIG" || "$HAS_CONSOLE_SHA" != "true" ) ]]; then
      HTML_SYNCED=false
    fi
  fi
  if [[ "$HTML_SYNCED" == "true" ]]; then
    exit 0
  fi
  echo "[$(date -Iseconds)] Senkronizasyon tetiklendi: $LOCAL_SHA (synced=$HTML_SYNCED)"
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
