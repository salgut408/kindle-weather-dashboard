#!/bin/sh
# render.sh — VIEW LAYER: Swiss-typographic layout via FBInk TrueType.
# Reads cache/data.env (from parse.lua / parse-nfl.lua). Change this file to
# restyle without touching the data layer.
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
d "$F_MED"   30 172 "$M" "$CUR_DATE   ·   $CUR_TIME"

# ================= HERO ===================
d "$F_HEAVY" 300 232 "$M" "${CUR_TEMP}°"
d "$F_ICON"  150 296 560 "$CUR_ICON"
HX=760
d "$F_BOLD" 46 262 "$HX" "$CUR_COND"
d "$F_MED"  34 342 "$HX" "FEELS ${CUR_FEELS}°"
d "$F_MED"  34 394 "$HX" "H ${TODAY_HI}°    L ${TODAY_LO}°"
d "$F_REG"  30 452 "$HX" "HUMIDITY ${CUR_HUM}%"
d "$F_REG"  30 494 "$HX" "WIND ${CUR_WIND} MPH"

# ================= HOURLY =================
d "$F_BOLD" 28 584 "$M" "HOURLY"
HN=${HOURLY_N:-0}
if [ "$HN" -gt 0 ]; then
  CW=$(( (SCREEN_W - 2*M) / HN ))
  i=1
  while [ "$i" -le "$HN" ]; do
    x=$(( M + (i-1)*CW ))
    d "$F_MED"  28 632 "$x" "$(col "$H_TIME" "$i")"
    d "$F_BOLD" 46 670 "$x" "$(col "$H_TEMP" "$i")°"
    d "$F_REG"  24 728 "$x" "$(col "$H_POP" "$i")%"
    i=$((i+1))
  done
fi

# ================= 5-DAY ==================
d "$F_BOLD" 28 814 "$M" "5-DAY FORECAST"
DN=${DAILY_N:-0}
if [ "$DN" -gt 0 ]; then
  i=1
  while [ "$i" -le "$DN" ]; do
    y=$(( 864 + (i-1)*64 ))
    d "$F_BOLD" 38 "$y"     "$M" "$(col "$D_DAY" "$i")"
    d "$F_MED"  38 "$y"     360 "$(col "$D_HI" "$i")°"
    d "$F_REG"  38 "$y"     490 "$(col "$D_LO" "$i")°"
    d "$F_REG"  28 $((y+6)) 660 "$(col "$D_POP" "$i")%  PRECIP"
    i=$((i+1))
  done
fi

# ================= NFL (2 columns, up to 7 per column) ========
NN=${NFL_N:-0}
if [ "$NN" -gt 0 ]; then
  d "$F_BOLD" 28 1206 "$M" "NFL   ·   ${NFL_WEEK}"
  ROWS=7
  COL2_X=640
  i=1
  while [ "$i" -le "$NN" ]; do
    eval "g=\${NFL_G$i}"
    if [ "$i" -le "$ROWS" ]; then x="$M"; r="$i"; else x="$COL2_X"; r=$(( i - ROWS )); fi
    y=$(( 1256 + (r-1)*44 ))
    d "$F_MED" 32 "$y" "$x" "$g"
    i=$((i+1))
  done
fi

# ================= FOOTER =================
FOOT="UPDATED $CUR_TIME   ·   OPEN-METEO + ESPN"
[ "${STALE:-0}" = "1" ] && FOOT="UPDATED $CUR_TIME   ·   OFFLINE — LAST KNOWN"
d "$F_REG" 26 1596 "$M" "$FOOT"
