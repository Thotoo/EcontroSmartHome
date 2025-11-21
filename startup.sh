#!/bin/sh

PIDFILE="/tmp/meter_poll.pid"
INTERVAL=10
LOGFILE="/tmp/meter_poll.log"

start() {
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo "Already running (PID $PID)"
      exit 1
    else
      echo "Removing stale PID file"
      rm -f "$PIDFILE"
    fi
  fi

  echo "Starting meter polling..."
  (
    while true; do
      lua /tmp/main.lua >> "$LOGFILE" 2>&1
      sleep $INTERVAL
    done
  ) &
  echo $! > "$PIDFILE"
}

stop() {
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    echo "Stopping meter polling..."
    # Kill the main loop
    kill "$PID" 2>/dev/null
    # Also try to kill its children (sleep/lua) via ps
    for CHILD in $(ps | awk '{print $1 " " $3}' | awk -v p=$PID '$2==p {print $1}'); do
      kill "$CHILD" 2>/dev/null
    done
    rm -f "$PIDFILE"
  else
    echo "Not running"
  fi
}


status() {
  if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "Meter polling is running (PID $(cat "$PIDFILE"))"
  else
    echo "Meter polling is stopped"
  fi
}

case "$1" in
  start) start ;;
  stop) stop ;;
  status) status ;;
  *) echo "Usage: $0 {start|stop|status}" ;;
esac
