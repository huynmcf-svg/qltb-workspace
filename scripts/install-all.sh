#!/usr/bin/env bash
# Cài dependency cho mọi sub-repo có package.json.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

install_repo() {
  local repo="$1"
  [ -f "$repo/package.json" ] || { echo "→ ${repo}: chưa có package.json, bỏ qua."; return; }
  echo "→ ${repo}: cài dependency..."
  if [ -f "$repo/package-lock.json" ]; then
    (cd "$repo" && npm ci)
  else
    (cd "$repo" && npm install)
  fi
}

install_repo "$SERVICE_REPO"
install_repo "$WEB_REPO"

echo
echo "  Xong. Chạy ./scripts/db-migrate.sh rồi ./scripts/start-all.sh."
