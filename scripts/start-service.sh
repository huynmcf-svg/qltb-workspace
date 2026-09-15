#!/usr/bin/env bash
# Chạy qltb-service ở chế độ dev. Log ra scripts/logs/service.log
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

[ -f "$SERVICE_REPO/package.json" ] || { echo "${SERVICE_REPO} chưa có package.json."; exit 1; }
[ -f "$SERVICE_REPO/.env" ] || { echo "Thiếu ${SERVICE_REPO}/.env — cp ${SERVICE_REPO}/.env.example ${SERVICE_REPO}/.env"; exit 1; }

mkdir -p scripts/logs
PIDFILE="scripts/logs/service.pid"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "service đang chạy sẵn (pid $(cat "$PIDFILE")). Dừng bằng ./scripts/stop-all.sh"
  exit 0
fi

echo "→ service khởi động trên :${SERVICE_PORT} ..."
(cd "$SERVICE_REPO" && PORT="$SERVICE_PORT" npm run start:dev) > scripts/logs/service.log 2>&1 &
echo $! > "$PIDFILE"
echo "  pid $(cat "$PIDFILE")  ·  log: scripts/logs/service.log"
