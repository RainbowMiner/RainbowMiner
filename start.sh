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
# glibc keeps freed memory in one malloc arena per busy thread, and .NET double-maps its JIT code
# for W^X: on a 6 GPU rig that was about 500 MB and 100 MB of resident memory nothing used
# (2026-09-28). A value already set in the environment wins
export MALLOC_ARENA_MAX=${MALLOC_ARENA_MAX:-2}
export DOTNET_EnableWriteXorExecute=${DOTNET_EnableWriteXorExecute:-0}

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

while true; do

  pwsh -ExecutionPolicy bypass -Command ${command}

  if [ "$?" != "99" ]; then
    break
  fi

done

exit
}
