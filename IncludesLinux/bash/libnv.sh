#!/usr/bin/env bash

nv_cudalibs="https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.04.18-cudalibs/cudalibs-linux-20240418.tar.gz"

if ! command -v wget &>/dev/null; then
    printf "Error: wget is not installed. Please install it and try again.\n" >&2
    exit 1
fi

if ! command -v tar &>/dev/null; then
    printf "Error: tar is not installed. Please install it and try again.\n" >&2
    exit 1
fi

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
    nv_present=1
else
    nv_present=0
fi

install_nv=0
quiet=0

while getopts "fq" opt; do
    case "$opt" in
        f) install_nv=1 ;;
        q) quiet=1 ;;
        *) echo "Usage: $0 [-f] [-q]" >&2; exit 1 ;;
    esac
done

target_folder="$(dirname "$0")/../lib"
uri_file="$target_folder/_uri.txt"

mkdir -p "$target_folder"

if [ "$nv_present" -eq 1 ] && [ "$install_nv" -eq 0 ]; then
  install_nv=1
  if [ -f "$uri_file" ]; then
    current_uri=$(cat "$uri_file" 2>/dev/null)
    if [ "$current_uri" = "$nv_cudalibs" ]; then
      install_nv=0
    fi
  fi
fi

exit_status=1

if [ "$install_nv" -eq 1 ]; then
  printf "\nDownloading %s\n" "$nv_cudalibs"

  if [ "$quiet" -eq 0 ]; then
    wget -q -O "$target_folder/cudalibs.tar.gz" "$nv_cudalibs" &
    wget_pid=$!  # Get the PID of the wget process

    while kill -0 "$wget_pid" 2>/dev/null; do
      for char in / - \\ \|; do
        printf "\rPlease wait .. %s" "$char"
        sleep 0.1
      done
    done
    wait $wget_pid

    status=$?

    printf "\r%40s\r" ""
  else
    wget -q -O "$target_folder/cudalibs.tar.gz" "$nv_cudalibs"
    status=$?
  fi

  if [ "$status" -eq 0 ]; then
    printf "Unpacking the archive now ..\n"
    tar -xzf "$target_folder/cudalibs.tar.gz" -C "$target_folder"
    status=$?
    if [ "$status" -eq 0 ]; then
      echo "$nv_cudalibs" > "$uri_file"
      printf "Successfully updated Nvidia CUDA libs!\n"
      exit_status=0
    else
      printf "Unpacking failed!\n"
    fi
  else
    printf "Download failed!\n"
  fi
  rm -f "$target_folder/cudalibs.tar.gz"
else
  printf "Nothing to do\n"
fi

exit $exit_status
