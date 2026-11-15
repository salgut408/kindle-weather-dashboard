#!/bin/sh
# fetch.sh — DATA LAYER: pull Open-Meteo forecast, cache it atomically.
# Exit: 0 fresh ok | 10 fetch failed but stale cache exists | 1 no data at all
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
mkdir -p "$CACHE_DIR" "$(dirname "$LOG_FILE")"

URL="https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}&timezone=${TZ_NAME}&temperature_unit=${TEMP_UNIT}&wind_speed_unit=${WIND_UNIT}&precipitation_unit=${PRECIP_UNIT}&timeformat=unixtime&forecast_days=${FORECAST_DAYS}&current=temperature_2m,apparent_temperature,relative_humidity_2m,is_day,precipitation,weather_code,wind_speed_10m,wind_direction_10m&hourly=temperature_2m,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"

TMP="$CACHE_DIR/weather.tmp.$$"
if curl -s --max-time 20 -o "$TMP" "$URL" && grep -q '"current"' "$TMP" 2>/dev/null; then
  mv "$TMP" "$CACHE_FILE"
  date +%s > "$CACHE_DIR/last_fetch"
  echo 1 > "$CACHE_DIR/fetch_ok"
  echo "$(date '+%Y-%m-%d %H:%M:%S') fetch ok" >> "$LOG_FILE"
  exit 0
fi

rm -f "$TMP"
echo 0 > "$CACHE_DIR/fetch_ok"
echo "$(date '+%Y-%m-%d %H:%M:%S') fetch FAILED" >> "$LOG_FILE"
[ -f "$CACHE_FILE" ] && exit 10
exit 1
