#!/bin/sh
# dashboard-worker.sh — the background refresh loop body. Redraws the
# dashboard, then sleeps REFRESH_MIN minutes, forever. Started/stopped by
# dashboard-loop.sh (don't run this directly).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
REFRESH_MIN=${REFRESH_MIN:-30}

while :; do
  "$ROOT/bin/dashboard.sh"
  sleep $((REFRESH_MIN * 60))
done
