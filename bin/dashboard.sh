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

# 4. pick the character outfit (SELECTION layer — independent of rendering).
#    Weather situation -> an image path. Never blocks the weather dashboard.
CHAR_IMG=""
if [ "${CHAR_ENABLED:-0}" = "1" ]; then
  CHAR_OUT=$(WIND_THRESH="$WIND_THRESH" HARD_WIND="$HARD_WIND" HARD_WIND_SHIFT="$HARD_WIND_SHIFT" \
    OUTFIT_HISTORY_N="$OUTFIT_HISTORY_N" OUTFIT_STABILITY_HOURS="$OUTFIT_STABILITY_HOURS" \
    LD_LIBRARY_PATH="$LUAJIT_LIBS" "$LUAJIT" "$ROOT/bin/pick-outfit.lua" "$ROOT" "$CACHE_DIR/data.env" \
    2>>"$LOG_FILE")
  CHAR_IMG=$(echo "$CHAR_OUT" | sed -n 's/^CHAR_IMG="\(.*\)"$/\1/p')
fi

# 5. render weather TEXT (FBInk), leaving the character slot empty
"$ROOT/bin/render.sh"

# 6. blit the character into its slot with eips (FBInk here is Image=No).
#    Dashboard stays usable if the asset is missing.
if [ -n "$CHAR_IMG" ] && [ -f "$ROOT/$CHAR_IMG" ]; then
  "$EIPS" -N 0 -g "$ROOT/$CHAR_IMG" -x "$CHAR_X" -y "$CHAR_Y" >/dev/null 2>&1
  echo "$(date '+%Y-%m-%d %H:%M:%S') render ok (stale=$STALE, char=$CHAR_IMG)" >> "$LOG_FILE"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') render ok (stale=$STALE, no character)" >> "$LOG_FILE"
fi
