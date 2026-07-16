#!/bin/bash
# vol.sh — ajudante do sink de saída (pactl). Contrato de saída INALTERADO: o
# ramo "volume" cospe um só token "NN%" (os chamadores Lua o normalizam por gsub).
# CORRECÇÃO (Braga Us): os ramos de escripta jaziam envoltos em $( … ), que captura
# a saída do comando e TENTA executá-la como sentença — inerte só por acaso (pactl
# set-* nada imprime). Ora corre-se o comando directamente; e todo argumento vae
# entre aspas, que um id de nó com brancos não se estilhace em palavras.

SINK="$(LC_ALL=C pactl get-default-sink)"

case "$1" in

  "volume")
    echo "$(LC_ALL=C pactl get-sink-volume "$SINK" | awk '{print $5}')"
  ;;

  "mute")
    echo "$(LC_ALL=C pactl get-sink-mute "$SINK")"
  ;;

  "set_sink")
    LC_ALL=C pactl set-default-sink "$2"
  ;;
esac
