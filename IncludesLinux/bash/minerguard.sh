#!/bin/sh
#
# minerguard.sh - stops a miner when RainbowMiner itself has gone away (POSIX sh)
#
# RainbowMiner starts every Linux miner inside a tmux or screen session, so the
# miner is not its child and would keep running after a crash of the core. This
# guard waits until either the miner or the controller exits; when the controller
# is gone first, the miner is stopped the same way RainbowMiner stops it: Ctrl-C
# into the session, then start-stop-daemon, then kill -9, then the session.
#
# usage: minerguard.sh <controller_pid> <miner_pid> <miner_name> <tmux|screen> <session> <pidfile> [<ocdcmd_dir> <ocd_prefix>]
#
# With <ocdcmd_dir> the kill commands are handed to the ocdaemon (miners running as
# root), otherwise they run directly.

ctl="$1"; pid="$2"; name="$3"; tool="$4"; sess="$5"; pidfile="$6"; ocddir="$7"; ocdpre="$8"

[ -n "$ctl" ] && [ -n "$pid" ] && [ -n "$tool" ] && [ -n "$sess" ] || exit 1

# /proc instead of kill -0: the miner may belong to root (ocdaemon) while the guard runs as the mining user
alive() { [ -d "/proc/$1" ]; }

# /proc/<pid>/comm carries the first 15 characters of the name: guard against a reused pid
name15="$(printf '%s' "$name" | cut -c1-15)"
mine() {
  alive "$pid" || return 1
  comm="$(cat "/proc/$pid/comm" 2>/dev/null)"
  [ -z "$name15" ] || [ -z "$comm" ] || [ "$name15" = "$comm" ]
}

while alive "$ctl" && mine; do
  sleep 2
done

# the miner ended on its own (or RainbowMiner stopped it): nothing to do
mine || exit 0

killseq() {
  echo '#!/bin/sh'
  if [ "$tool" = "tmux" ]; then
    echo "tmux send-keys -t '$sess' C-c >/dev/null 2>&1"
  else
    echo "screen -S '$sess' -X stuff '^C' >/dev/null 2>&1"
  fi
  echo "n=0; while [ -d /proc/$pid ] && [ \$n -lt 10 ]; do sleep 1; n=\$((n+1)); done"
  if command -v start-stop-daemon >/dev/null 2>&1 && [ -n "$pidfile" ]; then
    echo "[ -d /proc/$pid ] && start-stop-daemon --stop --name '$name' --pidfile '$pidfile' --retry 5 >/dev/null 2>&1"
  fi
  echo "for p in \$(pgrep -P $pid 2>/dev/null) $pid; do [ -d /proc/\$p ] && kill -9 \$p 2>/dev/null; done"
  if [ "$tool" = "tmux" ]; then
    echo "tmux kill-session -t '$sess' >/dev/null 2>&1"
  else
    echo "screen -S '$sess' -X quit >/dev/null 2>&1"
  fi
  echo "exit 0"
}

if [ -n "$ocddir" ] && [ -d "$ocddir" ]; then
  # the ocdaemon runs and removes every .sh it finds in its folder, as root
  f="$ocddir/${ocdpre:-guard}.guard.$sess.sh"
  killseq > "$f.tmp" && chmod 777 "$f.tmp" && mv "$f.tmp" "$f"
else
  killseq | sh
fi

# give the stop up to half a minute, then leave; the pid file is cleaned up by the next start
n=0
while mine && [ $n -lt 30 ]; do sleep 1; n=$((n+1)); done
[ -n "$f" ] && rm -f "$f" "$f.out" 2>/dev/null
exit 0
