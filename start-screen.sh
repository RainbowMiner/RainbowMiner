#!/usr/bin/env bash

cd "$(dirname "$0")"

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

! command -v screen >/dev/null 2>&1 && { echo "screen command not installed!"; exit 1; }

if ! test -f "/opt/rainbowminer/lib"
then
        screen_dir="$HOME/.screen"
        if ! test -d "$screen_dir"
        then
                mkdir "$screen_dir"
                chmod 700 "$screen_dir"
        fi
        export SCREENDIR="$screen_dir"
fi

screen -wipe >/dev/null 2>&1
screen -S RainbowMiner -d -m ./start.sh
