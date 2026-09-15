#!/usr/bin/env bash
# Chạy migration của qltb-service.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

[ -f "$SERVICE_REPO/.env" ] || { echo "Thiếu ${SERVICE_REPO}/.env — cp ${SERVICE_REPO}/.env.example ${SERVICE_REPO}/.env"; exit 1; }
[ -d "$SERVICE_REPO/node_modules" ] || { echo "Chưa cài dependency — chạy ./scripts/install-all.sh"; exit 1; }

(cd "$SERVICE_REPO" && npm run db:migrate)
