#!/bin/sh
# dashboard.sh — ORCHESTRATOR: fetch -> parse -> render, with cache fallback.
# Run this to (re)draw the dashboard. Safe to call repeatedly.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
mkdir -p "$CACHE_DIR" "$(dirname "$LOG_FILE")"

# 1. fetch (tolerate stale cache)
"$ROOT/bin/fetch.sh"; FETCH=$?
if [ "$FETCH" -eq 1 ]; then
  # no data at all — show a clean message instead of a blank screen
  "$FBINK" -q -c >/dev/null 2>&1
  "$FBINK" -q -t regular="$F_MED",px=44,top=120,left="$MARGIN",right=$((SCREEN_W-MARGIN)),bottom="$SCREEN_H" -- "NO WEATHER DATA" >/dev/null 2>&1
  "$FBINK" -q -t regular="$F_REG",px=30,top=190,left="$MARGIN",right=$((SCREEN_W-MARGIN)),bottom="$SCREEN_H" -- "Check Wi-Fi, then run dashboard.sh again." >/dev/null 2>&1
  echo "$(date '+%Y-%m-%d %H:%M:%S') render SKIPPED (no data)" >> "$LOG_FILE"
  exit 1
fi

# 2. parse cached JSON -> data.env
if ! LD_LIBRARY_PATH="$LUAJIT_LIBS" "$LUAJIT" "$ROOT/bin/parse.lua" "$ROOT" "$HOURLY_COUNT" \
      > "$CACHE_DIR/data.env" 2>>"$LOG_FILE"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') parse FAILED" >> "$LOG_FILE"
  exit 2
fi

# 3. stale flag (fetch failed but we rendered from old cache)
STALE=0
[ "$FETCH" -eq 10 ] && STALE=1
export STALE

# 4. render
"$ROOT/bin/render.sh"
echo "$(date '+%Y-%m-%d %H:%M:%S') render ok (stale=$STALE)" >> "$LOG_FILE"
