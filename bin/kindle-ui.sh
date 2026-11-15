#!/bin/sh
# kindle-ui.sh {stop|start} — stop/start the Kindle GUI framework so the
# dashboard can own the screen (no touch-to-home, no repaints).
# REVERSIBLE: `start` brings the normal Kindle UI back (so does a reboot).
#   stop   -> dedicated dashboard mode (Kindle is not a reader until start)
#   start  -> back to normal Kindle
case "$1" in
  stop)
    # lab126_gui is the parent that respawns framework/pillow — stop it too
    stop lab126_gui 2>/dev/null
    stop pillow     2>/dev/null
    stop framework  2>/dev/null
    echo "Kindle UI stopped — dashboard owns the screen"
    ;;
  start)
    start lab126_gui 2>/dev/null
    start framework  2>/dev/null
    start pillow     2>/dev/null
    echo "Kindle UI started — normal Kindle restored"
    ;;
  *)
    echo "usage: $0 {stop|start}"; exit 1 ;;
esac
