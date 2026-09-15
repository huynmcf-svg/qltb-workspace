#!/usr/bin/env bash
# Chạy qltb-web ở chế độ dev. Log ra scripts/logs/web.log
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

[ -f "$WEB_REPO/package.json" ] || { echo "${WEB_REPO} chưa có package.json."; exit 1; }

mkdir -p scripts/logs
PIDFILE="scripts/logs/web.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "web đang chạy sẵn (pid $(cat "$PIDFILE")). Dừng bằng ./scripts/stop-all.sh"
  exit 0
fi

echo "→ web khởi động trên :${WEB_PORT} ..."
(cd "$WEB_REPO" && npm run dev -- --port "$WEB_PORT") > scripts/logs/web.log 2>&1 &
echo $! > "$PIDFILE"
echo "  pid $(cat "$PIDFILE")  ·  log: scripts/logs/web.log"
