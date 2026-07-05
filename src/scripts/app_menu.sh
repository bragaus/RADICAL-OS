#!/usr/bin/env bash
# rofi app launcher ordered most-used -> least-used.
# Lists apps via app_usage.py (usage-sorted), lets rofi pick, then launches +
# bumps the count through the SAME store the carousel widget uses.
DIR="$(cd "$(dirname "$0")" && pwd)"

# -format i => rofi returns the 0-based index in the ORIGINAL (unfiltered) list,
# so it still maps correctly after the user types to filter.
sel=$(python3 "$DIR/app_usage.py" list-rofi \
  | rofi -dmenu -i -show-icons -format i -p "" -theme ~/.config/rofi/rofi.rasi)

[ -n "$sel" ] && python3 "$DIR/app_usage.py" launch-index "$sel"
