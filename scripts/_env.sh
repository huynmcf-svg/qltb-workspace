#!/usr/bin/env bash
# Nạp .env của workspace và đặt mặc định. Source từ các script khác, không chạy trực tiếp.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[ -f .env ] || { echo "Thiếu .env — chạy: cp .env.example .env"; exit 1; }
set -a; . ./.env; set +a

: "${SERVICE_REPO:=../qltb-service}"
: "${WEB_REPO:=../qltb-web}"
: "${SERVICE_PORT:=3400}"
: "${WEB_PORT:=3401}"
: "${DB_HOST:=localhost}"
: "${DB_PORT:=5432}"
: "${DB_USER:=qltb}"
: "${DB_PASS:=qltb}"
: "${DB_NAME:=qltb}"
