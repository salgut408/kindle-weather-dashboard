#!/bin/sh
# render.sh — VIEW LAYER: Swiss-typographic weather layout via FBInk TrueType.
# Reads cache/data.env (from parse.lua). Draws TEXT only. The weather-dependent
# character is blitted separately by dashboard.sh with `eips` into the reserved
# upper-right slot (CHAR_X/CHAR_Y) — so this file leaves that area empty.
#
# FBInk TTF geometry: top/left/right/bottom are MARGINS (insets), not coords.
# Position via top=Y, left=X; -O = transparent background (blocks never erase
# neighbors).
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
. "$CACHE_DIR/data.env"

F="$FBINK"
M="$MARGIN"

d() {
  "$F" -q -O -t regular="$1",px="$2",top="$3",left="$4",right=10,bottom=10 -- "$5" >/dev/null 2>&1
}
col() { echo "$1" | cut -d' ' -f"$2"; }

"$F" -q -c >/dev/null 2>&1

# ===== HEADER (left) =====
d "$F_HEAVY" 72 56  "$M" "CHICAGO"
d "$F_MED"   28 150 "$M" "$CUR_DATE   ·   $CUR_TIME"

# ===== HERO (left column; right-upper is the character slot) =====
d "$F_HEAVY" 260 222 "$M" "${CUR_TEMP}°"
d "$F_ICON"  110 250 500 "$CUR_ICON"
d "$F_BOLD"  42 512 "$M" "$CUR_COND"
d "$F_MED"   32 578 "$M" "FEELS ${CUR_FEELS}°"
d "$F_MED"   32 625 "$M" "H ${TODAY_HI}°    L ${TODAY_LO}°"
d "$F_REG"   28 675 "$M" "HUMIDITY ${CUR_HUM}%"
d "$F_REG"   28 713 "$M" "WIND ${CUR_WIND} MPH"

# ===== HOURLY (full width, below the character slot) =====
d "$F_BOLD" 28 948 "$M" "HOURLY"
HN=${HOURLY_N:-0}
if [ "$HN" -gt 0 ]; then
  CW=$(( (SCREEN_W - 2*M) / HN ))
  i=1
  while [ "$i" -le "$HN" ]; do
    x=$(( M + (i-1)*CW ))
    d "$F_MED"  28 996  "$x" "$(col "$H_TIME" "$i")"
    d "$F_BOLD" 44 1036 "$x" "$(col "$H_TEMP" "$i")°"
    d "$F_REG"  24 1096 "$x" "$(col "$H_POP" "$i")%"
    i=$((i+1))
  done
fi

# ===== 5-DAY (full width) =====
d "$F_BOLD" 28 1190 "$M" "5-DAY FORECAST"
DN=${DAILY_N:-0}
if [ "$DN" -gt 0 ]; then
  i=1
  while [ "$i" -le "$DN" ]; do
    y=$(( 1240 + (i-1)*68 ))
    d "$F_BOLD" 38 "$y"     "$M" "$(col "$D_DAY" "$i")"
    d "$F_MED"  38 "$y"     360 "$(col "$D_HI" "$i")°"
    d "$F_REG"  38 "$y"     490 "$(col "$D_LO" "$i")°"
    d "$F_REG"  28 $((y+6)) 660 "$(col "$D_POP" "$i")%  PRECIP"
    i=$((i+1))
  done
fi

# ===== FOOTER =====
FOOT="UPDATED $CUR_TIME   ·   OPEN-METEO"
[ "${STALE:-0}" = "1" ] && FOOT="UPDATED $CUR_TIME   ·   OFFLINE — LAST KNOWN"
d "$F_REG" 26 1600 "$M" "$FOOT"
