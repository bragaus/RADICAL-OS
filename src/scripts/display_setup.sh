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
      --output DP-0 --primary --mode 3440x1440 --rate 165 --pos 0x0 --rotate normal \
      --output HDMI-0 --mode 1920x1080 --rate 60 --rotate left --pos 3440x0
    if command -v nvidia-settings >/dev/null 2>&1; then
      nvidia-settings --assign "CurrentMetaMode=DP-0: 3440x1440_165 +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}, HDMI-0: 1920x1080 +3440+0 {Rotation=left, ForceCompositionPipeline=On}" >/dev/null 2>&1
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

# ── Verificação do refresh: garante 165Hz no DP-0 ─────────────────────────────
# 60Hz é o modo EDID-preferred deste monitor → se a atribuição falhar, o X cai
# silenciosamente para 60Hz (perde-se 105Hz sem erro). O guard acima ("primary
# != DP-0") nem reatribui se DP-0 já é primary mas travou em 60Hz. Aqui medimos o
# rate ATIVO e, se não for ~165, reforçamos a atribuição e avisamos.
dp0_active_rate() {
  xrandr --query | awk '
    /^DP-0 connected/ { f = 1; next }
    /^[^ ]/           { f = 0 }
    f && /\*/ { for (i = 1; i <= NF; i++) if ($i ~ /\*/) { gsub(/[*+]/, "", $i); print int($i); exit } }
  '
}

if [ "$DP0_CONNECTED" = "1" ]; then
  rate=$(dp0_active_rate)
  if [ -z "$rate" ] || [ "$rate" -lt 160 ]; then
    xrandr --output DP-0 --primary --mode 3440x1440 --rate 165 >/dev/null 2>&1
    if command -v nvidia-settings >/dev/null 2>&1; then
      nvidia-settings --assign "CurrentMetaMode=DP-0: 3440x1440_165 +0+0 {ForceCompositionPipeline=On, ForceFullCompositionPipeline=On}" >/dev/null 2>&1
    fi
    rate=$(dp0_active_rate)
    if [ -z "$rate" ] || [ "$rate" -lt 160 ]; then
      command -v notify-send >/dev/null 2>&1 && \
        notify-send -u critical "RADICAL-WM" "DP-0 não está em 165Hz (atual: ${rate:-?}Hz). Verifique cabo/EDID." >/dev/null 2>&1
      echo "[display_setup] AVISO: DP-0 em ${rate:-?}Hz, esperado 165Hz" >&2
    fi
  fi
fi
