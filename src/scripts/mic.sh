#!/bin/bash
# mic.sh — ajudante do source de entrada (pactl). Contrato de saída INALTERADO: o
# ramo "volume" cospe um só token "NN%" (os chamadores Lua o normalizam por gsub).
# CORRECÇÃO (Braga Us): idem vol.sh — os ramos de escripta corriam dentro de $( … ),
# que captura e reexecuta a saída; ora invocam-se directos, com todo argumento
# entre aspas (id de nó e passo de volume a salvo de word-splitting).

SINK="$(LC_ALL=C pactl get-default-source)"

case "$1" in

  "volume")
    echo "$(LC_ALL=C pactl get-source-volume "$SINK" | awk '{print $5}')"
  ;;

  "mute")
    echo "$(LC_ALL=C pactl get-source-mute "$SINK")"
  ;;

  "toggle_mute")
    LC_ALL=C pactl set-source-mute "$SINK" toggle
  ;;

  "set_volume")
    LC_ALL=C pactl set-source-volume "$SINK" "$2"
  ;;

  "set_source")
    LC_ALL=C pactl set-default-source "$2"
  ;;

esac
