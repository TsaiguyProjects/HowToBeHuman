#!/usr/bin/env bash
# Publish a timestamped content version to the VPS content directory.
#
# Uploads CONTENT_SOURCE (default: ./content-source) to a hidden staging
# directory, then atomically renames it to VERSION (default: current UTC
# timestamp). The API automatically serves the newest valid timestamp.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

VPS_HOST="${VPS_HOST:?Set VPS_HOST to the VPS hostname or IP}"
VPS_USER="${VPS_USER:?Set VPS_USER to the SSH deployment user}"
CONTENT_DIR="${CONTENT_DIR:-/srv/how-to-be-human/content}"
VERSION="${VERSION:-$(date -u +%Y%m%dT%H%M%SZ)}"
CONTENT_SOURCE="${CONTENT_SOURCE:-content-source}"
SSH_KEY="${VPS_SSH_PRIVATE_KEY_FILE:-$HOME/.ssh/id_ed25519}"

if [[ "$CONTENT_SOURCE" == "content-source" && ! -d "$CONTENT_SOURCE" && -d "$ROOT_DIR/content-source" ]]; then
  CONTENT_SOURCE="$ROOT_DIR/content-source"
fi

for cmd in rsync ssh python3 mktemp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required." >&2
    exit 1
  fi
done

if [[ ! -r "$SSH_KEY" ]]; then
  echo "Error: SSH key not readable: $SSH_KEY" >&2
  exit 1
fi
if [[ ! -d "$CONTENT_SOURCE" ]]; then
  echo "Error: content source directory not found: $CONTENT_SOURCE" >&2
  exit 1
fi
if [[ ! "$CONTENT_DIR" =~ ^/[A-Za-z0-9/_-]+$ ]]; then
  echo "Error: CONTENT_DIR must be an absolute path containing only letters, digits, /, _ and -." >&2
  exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  echo "Error: VERSION must use YYYYMMDDTHHMMSSZ format." >&2
  exit 1
fi
python3 - "$VERSION" <<'PY'
import datetime
import sys

datetime.datetime.strptime(sys.argv[1], "%Y%m%dT%H%M%SZ")
PY

# Keep published content limited to the file types served by the backend.
# The source repository's .git metadata is not published.
if find "$CONTENT_SOURCE" -name .git -type d -prune -o -name .DS_Store -prune -o -type l -print | grep -q .; then
  echo "Error: content source must not contain symlinks." >&2
  exit 1
fi
unsupported_files="$(find "$CONTENT_SOURCE" -name .git -type d -prune -o -name '.DS_Store' -prune -o -type f ! -name '*.md' ! -name '*.mmd' ! -name '*.markdown' -print)"
if [[ -n "$unsupported_files" ]]; then
  echo "Error: unsupported files in content source:" >&2
  printf '%s\n' "$unsupported_files" >&2
  exit 1
fi

STAGING=".staging-$VERSION"
SSH=(ssh -i "$SSH_KEY" -o IdentitiesOnly=yes)
REMOTE="$VPS_USER@$VPS_HOST"

# Wrap ssh in a small executable so rsync does not have to parse a key path
# that may contain spaces or shell metacharacters (fixes SSH key quoting).
SSH_WRAPPER=""
cleanup() {
  [[ -n "${SSH_WRAPPER:-}" ]] && rm -f "$SSH_WRAPPER"
  "${SSH[@]}" "$REMOTE" "rm -rf '$CONTENT_DIR/$STAGING'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

SSH_WRAPPER="$(mktemp "${TMPDIR:-/tmp}/publish-content-ssh.XXXXXX")"
cat > "$SSH_WRAPPER" <<EOF
#!/usr/bin/env bash
exec ssh -i $(printf '%q' "$SSH_KEY") -o IdentitiesOnly=yes "\$@"
EOF
chmod +x "$SSH_WRAPPER"

printf 'Checking VPS content directory: %s\n' "$CONTENT_DIR"
if ! "${SSH[@]}" "$REMOTE" "bash -s" <<REMOTE
set -euo pipefail
test -d '$CONTENT_DIR' && test -w '$CONTENT_DIR'
REMOTE
then
  echo "Error: content directory must already exist and be writable on the VPS." >&2
  exit 1
fi

printf 'Checking that version %s is not already published...\n' "$VERSION"
if ! "${SSH[@]}" "$REMOTE" "bash -s" <<REMOTE
set -euo pipefail
if [[ -e '$CONTENT_DIR/$VERSION' ]]; then
  echo 'Error: version already exists: $VERSION' >&2
  exit 1
fi
REMOTE
then
  exit 1
fi

printf 'Uploading %s to staging directory %s...\n' "$CONTENT_SOURCE" "$STAGING"
rsync -a --delete --exclude='.git' --exclude='.DS_Store' \
  -e "$SSH_WRAPPER" \
  "$CONTENT_SOURCE/" "$REMOTE:$CONTENT_DIR/$STAGING/"

printf 'Atomically publishing %s...\n' "$VERSION"
if ! "${SSH[@]}" "$REMOTE" "bash -s" <<REMOTE
set -euo pipefail
if [[ -e '$CONTENT_DIR/$VERSION' ]]; then
  echo 'Error: version already exists: $VERSION' >&2
  exit 1
fi
mv '$CONTENT_DIR/$STAGING' '$CONTENT_DIR/$VERSION'
REMOTE
then
  exit 1
fi

printf 'Compressing older content versions to save space...\n'
if ! "${SSH[@]}" "$REMOTE" "bash -s" <<REMOTE
set -euo pipefail
cd '$CONTENT_DIR'
versions="\$(find . -maxdepth 1 -mindepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z' -print | sed 's|^\./||' | sort)"
if [[ -z "\$versions" ]]; then
  echo 'No version directories found.'
  exit 0
fi
latest="\$(printf '%s\n' "\$versions" | tail -n 1)"
while IFS= read -r dir; do
  [[ -z "\$dir" || "\$dir" == "\$latest" ]] && continue
  archive="\$dir.tar.gz"
  if [[ -e "\$archive" ]]; then
    if [[ -d "\$dir" ]]; then
      if tar -tzf "\$archive" >/dev/null 2>&1; then
        echo "Archive exists; removing uncompressed \$dir..."
        rm -rf "\$dir"
      else
        echo "Existing archive invalid; recompressing \$dir..."
        tar -czf "\$archive" "\$dir" && rm -rf "\$dir"
      fi
    else
      echo "Skipping \$dir (already compressed)"
    fi
    continue
  fi
  echo "Compressing \$dir..."
  tar -czf "\$archive" "\$dir"
  rm -rf "\$dir"
done <<< "\$versions"
echo 'Older content versions compressed.'
REMOTE
then
  echo "Warning: failed to compress older content versions." >&2
fi

printf 'Published content version %s to %s\n' "$VERSION" "$CONTENT_DIR"
