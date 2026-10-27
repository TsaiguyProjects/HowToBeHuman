#!/usr/bin/env bash
# Build and deploy the Compose application to an OVHcloud VPS over SSH.
# Content is external, read-only at runtime, and deliberately untouched here.
set -euo pipefail

VPS_HOST="${VPS_HOST:?Set VPS_HOST to the VPS hostname or IP}"
VPS_USER="${VPS_USER:?Set VPS_USER to the SSH deployment user}"
VPS_APP_DIR="${VPS_APP_DIR:-/opt/how-to-be-human}"
CONTENT_DIR="${CONTENT_DIR:-/srv/how-to-be-human/content}"
DOMAIN="${DOMAIN:-$VPS_HOST}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || date -u +%Y%m%dT%H%M%SZ)}"
SSH_KEY="${VPS_SSH_PRIVATE_KEY_FILE:-$HOME/.ssh/id_ed25519}"
PLATFORM="${PLATFORM:-linux/amd64}"

for cmd in docker ssh scp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required."
    exit 1
  fi
done

if [[ ! -r "$SSH_KEY" ]]; then
  echo "Error: SSH key not readable: $SSH_KEY"
  exit 1
fi
if [[ ! "$VPS_APP_DIR" =~ ^/[A-Za-z0-9/_-]+$ || ! "$CONTENT_DIR" =~ ^/[A-Za-z0-9/_-]+$ ]]; then
  echo "Error: VPS_APP_DIR and CONTENT_DIR must be absolute paths containing only letters, digits, /, _ and -."
  exit 1
fi
if [[ ! "$TAG" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "Error: TAG contains unsupported characters."
  exit 1
fi

BACKEND_IMAGE="how-to-be-human-backend:$TAG"
FRONTEND_IMAGE="how-to-be-human-frontend:$TAG"
ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/how-to-be-human-images.XXXXXX.tar.gz")"
trap 'rm -f "$ARCHIVE"' EXIT

SSH=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes)
SCP=(scp -i "$SSH_KEY" -o IdentitiesOnly=yes)
REMOTE="$VPS_USER@$VPS_HOST"

printf 'Checking VPS content directory (read-only app mount): %s\n' "$CONTENT_DIR"
"${SSH[@]}" "$REMOTE" "test -d '$CONTENT_DIR' && test -r '$CONTENT_DIR'" || {
  echo "Error: content directory must already exist and be readable on the VPS. Deploy does not create or modify it."
  exit 1
}

printf 'Building images for VPS deployment (%s) for platform %s...\n' "$TAG" "$PLATFORM"
docker build --platform "$PLATFORM" -f backend/Dockerfile -t "$BACKEND_IMAGE" .
docker build --platform "$PLATFORM" -f frontend/Dockerfile -t "$FRONTEND_IMAGE" .
docker save "$BACKEND_IMAGE" "$FRONTEND_IMAGE" | gzip > "$ARCHIVE"

printf 'Transferring application files and images to %s...\n' "$VPS_HOST"
"${SCP[@]}" docker-compose.prod.yml "$REMOTE:$VPS_APP_DIR/docker-compose.prod.yml"
"${SCP[@]}" Caddyfile "$REMOTE:$VPS_APP_DIR/Caddyfile"
"${SCP[@]}" "$ARCHIVE" "$REMOTE:$VPS_APP_DIR/images.tar.gz"

printf 'Loading images and restarting containers (content is preserved)...\n'
"${SSH[@]}" "$REMOTE" \
  "cd '$VPS_APP_DIR' && gzip -dc images.tar.gz | docker load && IMAGE_TAG='$TAG' CONTENT_DIR='$CONTENT_DIR' DOMAIN='$DOMAIN' docker compose -f docker-compose.prod.yml up -d --no-build && IMAGE_TAG='$TAG' CONTENT_DIR='$CONTENT_DIR' DOMAIN='$DOMAIN' docker compose -f docker-compose.prod.yml up -d --no-build --force-recreate caddy && rm -f images.tar.gz && docker compose -f docker-compose.prod.yml ps"

printf 'Deployment complete. Content remains under %s.\n' "$CONTENT_DIR"
