#!/bin/sh
# Keep adb connected to the Android container, then start ws-scrcpy.
set -eu

adb start-server
(
  while true; do
    adb connect "${ADB_DEVICE}" >/dev/null 2>&1 || true
    sleep 10
  done
) &

exec node index.js
