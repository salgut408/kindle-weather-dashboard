#!/bin/sh
# fetch-nfl.sh — DATA LAYER: pull ESPN NFL scoreboard (free, no key), cache it.
# Same endpoint as the NFLComposeApp project. Exit: 0 ok | 10 stale | 1 none.
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
mkdir -p "$CACHE_DIR"

URL="https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
TMP="$CACHE_DIR/nfl.tmp.$$"
if curl -s --max-time 20 -o "$TMP" "$URL" && grep -q '"events"' "$TMP" 2>/dev/null; then
  mv "$TMP" "$CACHE_DIR/nfl.json"
  exit 0
fi
rm -f "$TMP"
[ -f "$CACHE_DIR/nfl.json" ] && exit 10
exit 1
