#!/bin/sh
# render.sh — VIEW LAYER: Swiss-typographic weather layout via FBInk TrueType.
# Reads cache/data.env (from parse.lua). Change this file to restyle without
# touching the data layer.
#
# FBInk TTF geometry: top/left/right/bottom are MARGINS (insets from each
# edge), not coordinates. Position by top=Y, left=X; keep opposite margins
# small. -O (bgless) = transparent-background glyphs, so blocks never erase
# their neighbors.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
. "$CACHE_DIR/data.env"

F="$FBINK"
M="$MARGIN"

# d <font> <px> <top(Y)> <left(X)> <text>
d() {
  "$F" -q -O -t regular="$1",px="$2",top="$3",left="$4",right=10,bottom=10 -- "$5" >/dev/null 2>&1
}
col() { echo "$1" | cut -d' ' -f"$2"; }

"$F" -q -c >/dev/null 2>&1

# ================= HEADER =================
d "$F_HEAVY" 78 60  "$M" "CHICAGO"
d "$F_MED"   30 175 "$M" "$CUR_DATE   ·   $CUR_TIME"

# ================= HERO ===================
d "$F_HEAVY" 300 235 "$M" "${CUR_TEMP}°"
d "$F_ICON"  150 300 560 "$CUR_ICON"
HX=760
d "$F_BOLD" 46 265 "$HX" "$CUR_COND"
d "$F_MED"  34 345 "$HX" "FEELS ${CUR_FEELS}°"
d "$F_MED"  34 398 "$HX" "H ${TODAY_HI}°    L ${TODAY_LO}°"
d "$F_REG"  30 458 "$HX" "HUMIDITY ${CUR_HUM}%"
d "$F_REG"  30 500 "$HX" "WIND ${CUR_WIND} MPH"

# ================= HOURLY =================
d "$F_BOLD" 28 650 "$M" "HOURLY"
HN=${HOURLY_N:-0}
if [ "$HN" -gt 0 ]; then
  CW=$(( (SCREEN_W - 2*M) / HN ))
  i=1
  while [ "$i" -le "$HN" ]; do
    x=$(( M + (i-1)*CW ))
    d "$F_MED"  28 700 "$x" "$(col "$H_TIME" "$i")"
    d "$F_BOLD" 46 740 "$x" "$(col "$H_TEMP" "$i")°"
    d "$F_REG"  24 798 "$x" "$(col "$H_POP" "$i")%"
    i=$((i+1))
  done
fi

# ================= 5-DAY ==================
d "$F_BOLD" 28 920 "$M" "5-DAY FORECAST"
DN=${DAILY_N:-0}
if [ "$DN" -gt 0 ]; then
  i=1
  while [ "$i" -le "$DN" ]; do
    y=$(( 980 + (i-1)*82 ))
    d "$F_BOLD" 40 "$y"     "$M" "$(col "$D_DAY" "$i")"
    d "$F_MED"  40 "$y"     360 "$(col "$D_HI" "$i")°"
    d "$F_REG"  40 "$y"     490 "$(col "$D_LO" "$i")°"
    d "$F_REG"  30 $((y+6)) 660 "$(col "$D_POP" "$i")%  PRECIP"
    i=$((i+1))
  done
fi

# ================= FOOTER =================
FOOT="UPDATED $CUR_TIME   ·   OPEN-METEO"
[ "${STALE:-0}" = "1" ] && FOOT="UPDATED $CUR_TIME   ·   OFFLINE — LAST KNOWN"
d "$F_REG" 26 1575 "$M" "$FOOT"
