#!/usr/bin/env bash
{

cd "$(dirname "$0")"

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_WORKGROUP_SIZE=256
export CUDA_DEVICE_ORDER=PCI_BUS_ID
export RBM_STARTLOOP=1

if command -v screen >/dev/null 2>&1 && ! test -d "/opt/rainbowminer/lib"
then
        screen_dir="$HOME/.screen"
        if ! test -d "$screen_dir"
        then
                mkdir "$screen_dir"
                chmod 700 "$screen_dir"
        fi
        export SCREENDIR="$screen_dir"
fi

command="& {./RainbowMiner.ps1 -configfile ./Config/config.txt; exit \$lastexitcode}"

# watchdog: restarts pwsh after a crash, gives up after wd_failmax consecutive runs shorter than wd_minrun seconds
wd_failmax="${RBM_WD_FAILMAX:-5}"
wd_minrun="${RBM_WD_MINRUN:-120}"
wd_failcount=0

while true; do

  wd_start=$(date +%s)

  pwsh -ExecutionPolicy bypass -Command ${command}
  wd_code=$?

  # intentional restart (e.g. after update)
  if [ "$wd_code" = "99" ]; then
    wd_failcount=0
    continue
  fi

  # intentional exits: normal stop, SIGINT (130), SIGTERM (143), stopp.txt present
  if [ "$wd_code" = "0" ] || [ "$wd_code" = "130" ] || [ "$wd_code" = "143" ]; then
    break
  fi
  [ -f "stopp.txt" ] && break

  # unexpected exit -> watchdog path
  wd_runtime=$(( $(date +%s) - wd_start ))
  if [ "$wd_runtime" -ge "$wd_minrun" ]; then
    wd_failcount=0
  else
    wd_failcount=$((wd_failcount + 1))
  fi

  mkdir -p Logs

  if [ "$wd_failcount" -ge "$wd_failmax" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') watchdog: giving up after ${wd_failcount} rapid crashes (last exit code ${wd_code})" >> Logs/watchdog.txt
    break
  fi

  echo "RainbowMiner exited unexpectedly with code ${wd_code} after ${wd_runtime}s - restarting in 10 seconds"
  echo "$(date '+%Y-%m-%d %H:%M:%S') watchdog: pwsh exit code ${wd_code} after ${wd_runtime}s - restart (fails ${wd_failcount}/${wd_failmax})" >> Logs/watchdog.txt
  sleep 10

done

exit
}
