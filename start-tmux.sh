#!/usr/bin/env bash

cd "$(dirname "$0")"

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

! command -v tmux >/dev/null 2>&1 && { echo "tmux command not installed!"; exit 1; }

tmux list-sessions -F '#{session_name}' 2>/dev/null | while read -r session; do
    if ! tmux has-session -t "$session" 2>/dev/null; then
        tmux kill-session -t "$session" 2>/dev/null
        echo "Removed dead tmux session: $session"
    fi
done

if tmux has-session -t RainbowMiner 2>/dev/null; then
    tmux kill-session -t RainbowMiner
fi

tmux new-session -d -s RainbowMiner ./start.sh
