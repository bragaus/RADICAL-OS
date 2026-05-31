#!/bin/sh
# Software brightness for this machine: NVIDIA RTX 3060 desktop, external DP monitor,
# no hardware backlight (/sys/class/backlight is empty). Uses xrandr gamma on the
# primary output. No root / no pkexec needed. Value is persisted so we can read it back.

STATE="/tmp/awesome_brightness"

OUTPUT="$(xrandr --query | awk '/ connected primary/ {print $1; exit}')"
[ -z "$OUTPUT" ] && OUTPUT="$(xrandr --query | awk '/ connected/ {print $1; exit}')"

get() {
  if [ -f "$STATE" ]; then cat "$STATE"; else echo 100; fi
}

apply() {
  v="$1"
  [ "$v" -lt 10 ] && v=10   # floor: avoid a fully black screen
  [ "$v" -gt 100 ] && v=100
  echo "$v" > "$STATE"
  [ -n "$OUTPUT" ] && xrandr --output "$OUTPUT" --brightness "$(awk "BEGIN{printf \"%.2f\", $v/100}")"
  echo "$v"
}

case "$1" in
  get) get ;;
  set) apply "$2" ;;
  inc) apply "$(( $(get) + ${2:-10} ))" ;;
  dec) apply "$(( $(get) - ${2:-10} ))" ;;
  *)   get ;;
esac
