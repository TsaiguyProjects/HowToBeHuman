#!/bin/bash
# Deploy/refresh the MediaWiki stack on the VPS (runs ON the VPS, or via SSH from CI).
# Usage on VPS:  ./vps/deploy.sh  (from repo root, uses .env for DOMAIN/MW_* vars)
#
# First run: LocalSettings.php won't exist yet — the stack still starts, then
# visit https://$DOMAIN to run the web installer (DB host `db`, name/user/pass
# from .env), download LocalSettings.php, place it at ./wiki/LocalSettings.php
# on the VPS, and copy it into the volume (see vps/README.md).
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "❌ .env not found. Copy it first: cp .env.example .env  (set DOMAIN, MW_DB_PASSWORD, ...)"
  exit 1
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

: "${DOMAIN:?Set DOMAIN in .env (e.g. example.com)}"
: "${MW_DB_PASSWORD:?Set MW_DB_PASSWORD in .env}"

echo "🚀 Deploying MediaWiki (domain: $DOMAIN)..."
git pull --ff-only 2>/dev/null || echo "(not a git checkout or no remote — continuing with local files)"

# Custom extensions/skins mount from git — make sure the dirs exist so
# Docker doesn't create them as root-owned on first run.
mkdir -p wiki/extensions-custom wiki/skins-custom

echo "🏗️  Building + starting containers..."
docker compose -f docker-compose.prod.yml up -d

echo "⏳ Waiting for the wiki to respond..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:80/ >/dev/null 2>&1; then
    echo "✅ Wiki is responding on http://localhost:80/"
    break
  fi
  sleep 4
  if [ "$i" -eq 30 ]; then
    echo "❌ Wiki did not become healthy. Logs:"
    docker compose -f docker-compose.prod.yml logs --tail=50
    exit 1
  fi
done

if [ ! -f wiki/LocalSettings.php ]; then
  echo "⚠️  wiki/LocalSettings.php not found — fresh install."
  echo "   1. Visit https://$DOMAIN and run the web installer"
  echo "      (DB host: db | DB name/user/pass: from .env MW_DB_*)."
  echo "   2. Save the downloaded LocalSettings.php to ./wiki/ on the VPS,"
  echo "      then: docker cp ./wiki/LocalSettings.php \$(docker compose -f docker-compose.prod.yml ps -q wiki):/var/www/html/LocalSettings.php"
fi

echo "🌐 Public URL (after DNS propagates): https://$DOMAIN"
docker compose -f docker-compose.prod.yml ps
