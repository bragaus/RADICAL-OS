#!/bin/sh

# Push the NVIDIA RTX 3060 to maximum performance so graphics render faster
# (PowerMizer defaults to adaptive/mode 2; mode 1 = prefer maximum performance).
if command -v nvidia-settings >/dev/null 2>&1; then
  nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1
fi

is_connected() {
  xrandr --query | grep -E "^$1 connected" >/dev/null 2>&1
}

DP0_CONNECTED=0
HDMI0_CONNECTED=0
is_connected "DP-0" && DP0_CONNECTED=1
is_connected "HDMI-0" && HDMI0_CONNECTED=1

CURRENT_PRIMARY=$(xrandr --query | awk '/ connected primary/ {print $1}')

if [ "$DP0_CONNECTED" = "1" ] && [ "$HDMI0_CONNECTED" = "1" ]; then
  if [ "$CURRENT_PRIMARY" != "DP-0" ] || [ -z "$CURRENT_PRIMARY" ]; then
    xrandr \
      --output DP-0 --primary --mode 3440x1440 --rate 165 --pos 0x0 \
      --output HDMI-0 --mode 1920x1080 --rate 60 --pos 760x1440
    if command -v nvidia-settings >/dev/null 2>&1; then
      nvidia-settings --assign "CurrentMetaMode=DP-0: 3440x1440_165 +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, HDMI-0: 1920x1080 +760+1440 {ForceCompositionPipeline=On}" >/dev/null 2>&1
    fi
  fi
elif [ "$DP0_CONNECTED" = "1" ]; then
  if [ "$CURRENT_PRIMARY" != "DP-0" ]; then
    xrandr --output DP-0 --primary --mode 3440x1440 --rate 165 --pos 0x0
    if command -v nvidia-settings >/dev/null 2>&1; then
      nvidia-settings --assign "CurrentMetaMode=DP-0: 3440x1440_165 +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}" >/dev/null 2>&1
    fi
  fi
elif [ "$HDMI0_CONNECTED" = "1" ]; then
  if [ "$CURRENT_PRIMARY" != "HDMI-0" ]; then
    xrandr --output HDMI-0 --primary --mode 1920x1080 --rate 60 --pos 0x0
  fi
fi
