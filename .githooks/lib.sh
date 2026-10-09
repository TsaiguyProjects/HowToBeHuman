#!/usr/bin/env bash
# Shared helpers for the repo git hooks (.githooks/).
# Pure bash, no external dependencies beyond git itself.

HOOKS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HOOKS_ROOT/.." && pwd)"

_red() { printf '\033[0;31m%s\033[0m\n' "$*"; }
_green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
_info() { printf '  %s\n' "$*"; }

# require_cmd <binary> <install-hint>
# Abort with a helpful message when a tool is missing (common when git is
# invoked from GUI clients with a minimal PATH).
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    _red "✖ Required tool '$1' not found on PATH."
    _info "$2"
    _info "Bypass hooks for this run with: git <command> --no-verify"
    exit 1
  fi
}

NEED_VALIDATE=0
NEED_COMPOSE=0

# map_scopes: read newline-separated repo-relative paths on stdin and set
# NEED_VALIDATE (any non-docs change) and NEED_COMPOSE (compose stack changed,
# needs a Docker-based config check). Docs (*.md, LICENSE) select nothing.
map_scopes() {
  NEED_VALIDATE=0
  NEED_COMPOSE=0
  local file
  while IFS= read -r file || [ -n "$file" ]; do
    [ -z "$file" ] && continue
    case "$file" in
      *.md|LICENSE|.gitignore) ;;
      docker-compose*.yml|.env.example) NEED_VALIDATE=1; NEED_COMPOSE=1 ;;
      *) NEED_VALIDATE=1 ;;
    esac
  done
}

# check_shell: bash syntax check on the repo's shell scripts.
check_shell() {
  require_cmd bash "Bash is required (macOS: Xcode CLT, Linux: build-essential)."
  local f
  for f in vps/*.sh .githooks/pre-commit .githooks/pre-push .githooks/lib.sh; do
    [ -f "$REPO_ROOT/$f" ] || continue
    bash -n "$REPO_ROOT/$f" || { _red "✖ Syntax error in $f"; exit 1; }
  done
  _info "▸ shell syntax OK"
}

# check_compose: validate the prod stack resolves (dummy secrets, no daemon state touched).
check_compose() {
  require_cmd docker "Start the Docker daemon (Docker Desktop) and retry."
  MW_DB_PASSWORD=dummy-hook-check DOMAIN=example.invalid \
    docker compose -f "$REPO_ROOT/docker-compose.prod.yml" config --quiet \
    || { _red "✖ docker-compose.prod.yml is invalid"; exit 1; }
  _info "▸ compose config OK"
}
