#!/bin/bash
# pfp.sh — resolve o retrato (profile picture) e o nome do usuário.
# CORRECÇÃO (Braga Us): (1) todo printf de dado do usuário passa a printf '%s' —
# outr'ora o GECOS/HOME entravam como CADEIA DE FORMATO, onde um '%' ou '\' do
# nome faria o printf tropeçar ou consumir argumentos. (2) o teste do retrato
# cacheado incidia sobre o DIRECTÓRIO userpfp/ (com barra final), pelo que era
# sempre falso; ora incide sobre o ficheiro cacheado real "$USER.png".

case "$1" in

  "userPfp")
    iconPath="/var/lib/AccountsService/icons/$USER"
    userIconDir="$HOME/.config/awesome/src/assets/userpfp"
    cached="$userIconDir/$USER.png"

    if [[ -f "$iconPath" ]]; then
      # Havendo retrato de systema, mantém-se o cache em dia (copia se diferir).
      if ! cmp --silent "$cached" "$iconPath"; then
        mkdir -p "$userIconDir"
        cp "$iconPath" "$cached"
      fi
      printf '%s' "$cached"
    elif [[ -f "$cached" ]]; then
      # Sem retrato de systema, serve-se o cache pretérito, se o houver.
      printf '%s' "$cached"
    fi
  ;;

  "userName")
    fullname="$(getent passwd "$(whoami)" | cut -d ':' -f 5)"
    user="$(whoami)"
    host="$(hostname)"
    if [[ "$2" == "userhost" ]]; then
      printf '%s@%s' "$user" "$host"
    elif [[ "$2" == "fullname" ]]; then
      printf '%s' "$fullname"
    else
      printf '%s' "Rick Astley"
    fi
  ;;

esac
