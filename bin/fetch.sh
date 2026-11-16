#!/bin/sh
# fetch.sh — DATA LAYER: pull current + forecast from the US National Weather
# Service (api.weather.gov) — real observed station conditions, free, no key,
# no hard usage cap (requires a User-Agent). Caches raw JSON atomically.
# Exit: 0 fresh ok | 10 fetch failed but stale cache exists | 1 no data at all.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
mkdir -p "$CACHE_DIR" "$(dirname "$LOG_FILE")"

UA="User-Agent: kindle-weather-dashboard/1.0 (personal use)"
AC="Accept: application/geo+json"
G() { curl -s --max-time 25 -H "$UA" -H "$AC" "$1"; }
url_of() { grep -oE "\"$1\": *\"[^\"]*\"" "$2" | head -1 | sed 's/.*": *"//; s/"$//'; }

TMP="$CACHE_DIR/nws.tmp.$$"; mkdir -p "$TMP"; ok=1

# 1. resolve the gridpoint + forecast/observation URLs for this lat/lon
G "https://api.weather.gov/points/${LAT},${LON}" > "$TMP/points.json"
grep -q '"forecastHourly"' "$TMP/points.json" || ok=0
HOURLY=$(url_of forecastHourly "$TMP/points.json")
DAILY=$(url_of forecast "$TMP/points.json")
STNS=$(url_of observationStations "$TMP/points.json")

# 2. nearest observation station
[ -n "$STNS" ] && G "$STNS" > "$TMP/stns.json"
STID=$(grep -oE '"stationIdentifier": *"[^"]*"' "$TMP/stns.json" 2>/dev/null | head -1 | sed 's/.*": *"//; s/"$//')
[ -n "$STID" ] || ok=0

# 3. current observation + hourly + daily forecasts
[ -n "$STID" ]  && G "https://api.weather.gov/stations/${STID}/observations/latest" > "$TMP/obs.json"
[ -n "$HOURLY" ] && G "$HOURLY" > "$TMP/hourly.json"
[ -n "$DAILY" ]  && G "$DAILY"  > "$TMP/daily.json"
# sunrise/sunset (NWS has none) — free, no key, no limit. Optional: never fails the fetch.
curl -s --max-time 15 "https://api.sunrise-sunset.org/json?lat=${LAT}&lng=${LON}&formatted=0" > "$TMP/sun.json" 2>/dev/null
grep -q '"temperature"' "$TMP/obs.json"    2>/dev/null || ok=0
grep -q '"periods"'     "$TMP/hourly.json" 2>/dev/null || ok=0
grep -q '"periods"'     "$TMP/daily.json"  2>/dev/null || ok=0

if [ "$ok" = "1" ]; then
  mv "$TMP/obs.json" "$CACHE_DIR/obs.json"
  mv "$TMP/hourly.json" "$CACHE_DIR/hourly.json"
  mv "$TMP/daily.json" "$CACHE_DIR/daily.json"
  [ -s "$TMP/sun.json" ] && mv "$TMP/sun.json" "$CACHE_DIR/sun.json"
  rm -rf "$TMP"
  date +%s > "$CACHE_DIR/last_fetch"; echo 1 > "$CACHE_DIR/fetch_ok"
  echo "$(date '+%Y-%m-%d %H:%M:%S') nws fetch ok ($STID)" >> "$LOG_FILE"
  exit 0
fi

rm -rf "$TMP"; echo 0 > "$CACHE_DIR/fetch_ok"
echo "$(date '+%Y-%m-%d %H:%M:%S') nws fetch FAILED" >> "$LOG_FILE"
[ -f "$CACHE_DIR/obs.json" ] && exit 10
exit 1
