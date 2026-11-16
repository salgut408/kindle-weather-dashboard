#!/bin/sh
# dashboard-loop.sh {start|stop|status} — auto-refresh the dashboard every
# REFRESH_MIN minutes and keep it on screen (disable the screensaver while
# running). Detaches so it survives the SSH session closing.
#
#   start   begin the refresh loop + disable screensaver
#   stop    end the loop + re-enable screensaver
#   status  is it running?
#
# Tune the interval:  REFRESH_MIN=60 dashboard-loop.sh start
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ROOT/config.sh"
PIDFILE="$CACHE_DIR/loop.pid"
export REFRESH_MIN="${REFRESH_MIN:-60}"

prevent_ss() { lipc-set-prop com.lab126.powerd preventScreenSaver 1 2>/dev/null; }
allow_ss()   { lipc-set-prop com.lab126.powerd preventScreenSaver 0 2>/dev/null; }
running()    { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

case "$1" in
  start)
    if running; then echo "already running (pid $(cat "$PIDFILE"))"; exit 0; fi
    mkdir -p "$CACHE_DIR"
    prevent_ss
    # detach the worker so it keeps running after SSH disconnect
    if command -v setsid >/dev/null 2>&1; then
      setsid "$ROOT/bin/dashboard-worker.sh" >/dev/null 2>&1 </dev/null &
    else
      nohup "$ROOT/bin/dashboard-worker.sh" >/dev/null 2>&1 </dev/null &
    fi
    echo $! > "$PIDFILE"
    echo "started (pid $!) — refresh every ${REFRESH_MIN} min, screensaver off"
    ;;
  stop)
    if running; then
      PID=$(cat "$PIDFILE")
      kill -- -"$PID" 2>/dev/null || kill "$PID" 2>/dev/null   # kill group, then fallback
    fi
    rm -f "$PIDFILE"
    allow_ss
    echo "stopped — screensaver re-enabled"
    ;;
  status)
    if running; then echo "running (pid $(cat "$PIDFILE"))"; else echo "not running"; fi
    ;;
  *)
    echo "usage: $0 {start|stop|status}"; exit 1 ;;
esac
