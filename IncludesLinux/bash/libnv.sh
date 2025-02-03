#!/usr/bin/env bash

nv_cudalibs="https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.04.18-cudalibs/cudalibs-linux-20240418.tar.gz"

# Check for required commands
for cmd in wget tar; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf "Error: %s is not installed. Please install it and try again.\n" "$cmd" >&2
        exit 1
    fi
done

# Function to check for NVIDIA devices
check_lspci() {
    command -v lspci >/dev/null 2>&1 && lspci | grep -i nvidia >/dev/null 2>&1
}

check_nvidia_smi() {
    command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi --query-gpu=name --format=csv,noheader >/dev/null 2>&1
}

check_proc_sys() {
    grep -i nvidia /proc/driver/nvidia/version >/dev/null 2>&1 || \
    find /sys/class/drm/card*/device/vendor 2>/dev/null -exec grep -q '0x10de' {} +
}

# Detect NVIDIA presence
if check_lspci || check_nvidia_smi || check_proc_sys; then
    nv_present=1
else
    nv_present=0
fi

install_nv=0
quiet=0

# Parse options
while getopts "fq" opt; do
    case "$opt" in
        f) install_nv=1 ;;
        q) quiet=1 ;;
        *) printf "Usage: %s [-f] [-q]\n" "$0" >&2; exit 1 ;;
    esac
done

# Prepare paths
target_folder="$(dirname "$0")/../lib"
uri_file="$target_folder/_uri.txt"

mkdir -p "$target_folder"

# Check if CUDA libs need to be installed
if [ "$nv_present" -eq 1 ] && [ "$install_nv" -eq 0 ]; then
    install_nv=1
    if [ -f "$uri_file" ]; then
        current_uri=$(cat "$uri_file" 2>/dev/null)
        [ "$current_uri" = "$nv_cudalibs" ] && install_nv=0
    fi
fi

exit_status=1

# Download and install CUDA libs
if [ "$install_nv" -eq 1 ]; then
    [ "$quiet" -eq 0 ] && printf "\nDownloading %s\n" "$nv_cudalibs"
    wget_opts="-O "$target_folder/cudalibs.tar.gz""
    [ "$quiet" -eq 1 ] && wget_opts="-q $wget_opts"
    wget $wget_opts "$nv_cudalibs"

    if [ $? -eq 0 ]; then
        [ "$quiet" -eq 0 ] && printf "Unpacking the archive now ..\n"
        tar -xzf "$target_folder/cudalibs.tar.gz" -C "$target_folder"

        if [ $? -eq 0 ]; then
            echo "$nv_cudalibs" > "$uri_file"
            [ "$quiet" -eq 0 ] && printf "Successfully updated Nvidia CUDA libs!\n"
            exit_status=0
        else
            [ "$quiet" -eq 0 ] && printf "Unpacking failed!\n"
        fi
    else
        [ "$quiet" -eq 0 ] && printf "Download failed!\n"
    fi

    rm -f "$target_folder/cudalibs.tar.gz"
else
    [ "$quiet" -eq 0 ] && printf "Nothing to do\n"
fi

exit $exit_status
