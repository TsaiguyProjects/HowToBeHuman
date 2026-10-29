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

NEED_BACKEND=0
NEED_FRONTEND=0

# map_scopes: read newline-separated repo-relative paths on stdin and set
# NEED_BACKEND / NEED_FRONTEND. Docs-only and unrecognized files select nothing.
map_scopes() {
  NEED_BACKEND=0
  NEED_FRONTEND=0
  local file
  while IFS= read -r file || [ -n "$file" ]; do
    [ -z "$file" ] && continue
    case "$file" in
      backend/*) NEED_BACKEND=1 ;;
      frontend/*) NEED_FRONTEND=1 ;;
      Makefile|docker-compose.yml|.dockerignore|ovh/*|scripts/*|.github/*)
        NEED_BACKEND=1
        NEED_FRONTEND=1
        ;;
    esac
  done
}
