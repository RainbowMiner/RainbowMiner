#!/usr/bin/env bash

cuda_urls=(
    "https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.04.18-cudalibs/cudalibs-linux-20240418.tar.gz"
    "https://github.com/RainbowMiner/miner-binaries/releases/download/v2025.07.02-cudalibs/cudalibs-linux-12.5.82.tar.gz"
    "https://github.com/RainbowMiner/miner-binaries/releases/download/v2025.07.02-cudalibs/cudalibs-linux-12.6.85.tar.gz"
    "https://github.com/RainbowMiner/miner-binaries/releases/download/v2025.07.02-cudalibs/cudalibs-linux-12.8.83.tar.gz"
    "https://github.com/RainbowMiner/miner-binaries/releases/download/v2025.07.02-cudalibs/cudalibs-linux-12.9.86.tar.gz"
)

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
mkdir -p "$target_folder"


download_and_install() {
    local url="$1"
    local index="$2"
    local uri_file="$target_folder/_uri${index}.txt"
    [ "$index" -eq 1 ] && uri_file="$target_folder/_uri.txt"  # Ausnahme für erste URL

    local needs_install=0
    if [ "$install_nv" -eq 1 ]; then
        needs_install=1
    elif [ "$nv_present" -eq 1 ]; then
        if [ ! -f "$uri_file" ] || [ "$(cat "$uri_file")" != "$url" ]; then
            needs_install=1
        fi
    fi

    if [ "$needs_install" -eq 1 ]; then
        [ "$quiet" -eq 0 ] && printf "\nDownloading %s\n" "$url"
        local archive="$target_folder/cudalibs$index.tar.gz"
        local wget_opts="-O $archive"
        [ "$quiet" -eq 1 ] && wget_opts="-q $wget_opts"
        if wget $wget_opts "$url"; then
            [ "$quiet" -eq 0 ] && printf "Unpacking archive #%d ..\n" "$index"
            if tar -xzf "$archive" -C "$target_folder"; then
                echo "$url" > "$uri_file"
                [ "$quiet" -eq 0 ] && printf "Installed CUDA part #%d successfully!\n" "$index"
                rm -f "$archive"
                return 0
            else
                [ "$quiet" -eq 0 ] && printf "Unpacking archive #%d failed!\n" "$index"
            fi
            rm -f "$archive"
        else
            [ "$quiet" -eq 0 ] && printf "Download of archive #%d failed!\n" "$index"
        fi
        return 1
    else
        [ "$quiet" -eq 0 ] && printf "CUDA part #%d is up to date.\n" "$index"
        return 0
    fi
}

exit_status=0
i=1
for url in "${cuda_urls[@]}"; do
    if ! download_and_install "$url" "$i"; then
        exit_status=1
    fi
    i=$((i + 1))
done

exit $exit_status
