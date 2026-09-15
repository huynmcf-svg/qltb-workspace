#!/usr/bin/env bash
# Dừng service và web theo PID đã ghi lúc start.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

stop_one() {
  local name="$1"
  local pidfile="scripts/logs/${name}.pid"

  [ -f "$pidfile" ] || { echo "→ ${name}: không có pidfile, bỏ qua."; return; }

  local pid; pid="$(cat "$pidfile")"
  if kill -0 "$pid" 2>/dev/null; then
    # Kill cả cây tiến trình con — npm sinh process con, kill mỗi npm là để lại orphan.
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      pkill -KILL -P "$pid" 2>/dev/null || true
      kill -KILL "$pid" 2>/dev/null || true
    fi
    echo "→ ${name}: đã dừng (pid ${pid})."
  else
    echo "→ ${name}: tiến trình ${pid} không còn chạy."
  fi
  rm -f "$pidfile"
}

stop_one service
stop_one web
echo
echo "  Xong."
