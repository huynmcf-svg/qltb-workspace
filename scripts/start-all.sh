#!/usr/bin/env bash
# Khởi động cả service và web.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

./scripts/start-service.sh
./scripts/start-web.sh

cat <<MSG

  service : http://localhost:${SERVICE_PORT}      (swagger: /docs, health: /health)
  web     : http://localhost:${WEB_PORT}

  Xem log : tail -f scripts/logs/service.log
            tail -f scripts/logs/web.log
  Dừng    : ./scripts/stop-all.sh

MSG
