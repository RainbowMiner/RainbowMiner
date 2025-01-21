#!/usr/bin/env bash

nv_cudalibs="https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.04.18-cudalibs/cudalibs-linux-20240418.tar.gz"

check_lspci() {
    if command -v lspci &>/dev/null; then
        lspci | grep -i nvidia &>/dev/null && return 0
    fi
    return 1
}

check_nvidia_smi() {
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name --format=csv,noheader &>/dev/null && return 0
    fi
    return 1
}

check_proc_sys() {
    grep -i nvidia /proc/driver/nvidia/version &>/dev/null || \
    ls /sys/class/drm/card*/device/vendor 2>/dev/null | grep -q '0x10de'
}

if check_lspci || check_nvidia_smi || check_proc_sys; then
    nv_present=true
else
    nv_present=false
fi

install_nv=false
quiet=false

while getopts "fq" opt; do
    case "$opt" in
        f)  # Force
            install_nv=true
            ;;
        q)  # Quiet
            quiet=true
            ;;
        *)  # Invalid option
            echo "Usage: $0 [-f] [-q]" >&2
            exit 1
            ;;
    esac
done

target_folder="$(dirname "$0")/../lib"
uri_file="$target_folder/_uri.txt"

if $nv_present && ! $install_nv; then
  install_nv=true
  if [ -f "$uri_file" ]; then
    current_uri=$(cat "$uri_file" 2>/dev/null)
    if [ "$current_uri" = "$nv_cudalibs" ]; then
      install_nv=false
    fi
  fi
fi

if $install_nv; then
  printf "\nDownloading %s\n" "$nv_cudalibs"

  if [ "$quiet" = false ]; then
    wget -q -O "$target_folder/cudalibs.tar.gz" "$nv_cudalibs" &
    wget_pid=$!  # Get the PID of the wget process

    spinner="/-\|"
    while kill -0 $wget_pid 2>/dev/null; do
      for i in $(seq 0 3); do
          printf "\rPlease wait .. ${spinner:$i:1}"
          sleep 0.1
      done
    done

    wait $wget_pid

    status=$?

    printf "\r"
  else
    wget -q -O "$target_folder/cudalibs.tar.gz" "$nv_cudalibs"
    status=$?
  fi

  if [ $status -eq 0 ]; then
    printf "Unpacking the archive now ..\n"
    tar -xzf "$target_folder/cudalibs.tar.gz" -C "$target_folder"
    echo "$nv_cudalibs" > "$uri_file"
  else
    printf "Download failed!\n"
  fi

  rm -f "$target_folder/cudalibs.tar.gz"
fi
