#!/bin/sh
# deploy.sh — push runtime files from Mac to the Kindle over SSH (key auth).
# Deploys only what the dashboard needs to run; source stays on the Mac.
set -e
KHOST="${KINDLE_HOST:-root@192.168.1.50}"   # set KINDLE_HOST=root@<your-kindle-ip>
KEY="$HOME/.ssh/kindle_dashboard"
DEST="/mnt/us/dashboard"
SSHO="-i $KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"

ssh $SSHO "$KHOST" "mkdir -p $DEST/bin $DEST/assets $DEST/cache $DEST/logs"
scp $SSHO config.sh            "$KHOST:$DEST/config.sh"
scp $SSHO bin/fetch.sh bin/parse.lua bin/render.sh bin/dashboard.sh "$KHOST:$DEST/bin/"
scp $SSHO assets/json.lua      "$KHOST:$DEST/assets/json.lua"
ssh $SSHO "$KHOST" "chmod +x $DEST/bin/fetch.sh $DEST/bin/render.sh $DEST/bin/dashboard.sh"
echo "deployed to $KHOST:$DEST"
