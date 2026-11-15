#!/bin/sh
# ===== Kindle Weather Dashboard: configuration (single source of truth) =====

# ---- Location: Chicago, Illinois ----
LAT="41.8781"
LON="-87.6298"
TZ_NAME="America/Chicago"
TEMP_UNIT="fahrenheit"
WIND_UNIT="mph"
PRECIP_UNIT="inch"
FORECAST_DAYS="5"
HOURLY_COUNT="6"          # how many hourly columns to show
NFL_COUNT="14"            # how many NFL games to show (2-column layout)

# ---- On-Kindle paths (deploy target) ----
DASH_ROOT="/mnt/us/dashboard"
BIN_DIR="$DASH_ROOT/bin"
ASSET_DIR="$DASH_ROOT/assets"
CACHE_DIR="$DASH_ROOT/cache"
LOG_FILE="$DASH_ROOT/logs/dashboard.log"
CACHE_FILE="$CACHE_DIR/weather.json"      # last successful raw API response

# ---- Screen (Paperwhite 11th gen / PW5), portrait ----
SCREEN_W="1236"
SCREEN_H="1648"
MARGIN="80"

# ---- Tools ----
FBINK="/usr/local/bin/fbink"
LUAJIT="/mnt/us/koreader/luajit"
LUAJIT_LIBS="/mnt/us/koreader"            # LD_LIBRARY_PATH for luajit

# ---- Fonts (already on device: Amazon Ember, E-Ink optimized grotesque) ----
F_HEAVY="/usr/java/lib/fonts/Amazon-Ember-Heavy.ttf"
F_BOLD="/usr/java/lib/fonts/Amazon-Ember-Bold.ttf"
F_MED="/usr/java/lib/fonts/Amazon-Ember-Medium.ttf"
F_REG="/usr/java/lib/fonts/Amazon-Ember-Regular.ttf"
F_ICON="/mnt/us/koreader/fonts/nerdfonts/symbols.ttf"   # weather glyphs
