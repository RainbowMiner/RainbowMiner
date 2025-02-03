#!/usr/bin/env bash

# Move to script's directory
cd "$(dirname "$0")" || exit 1

# Add IncludesLinux/bin to PATH if not already present
case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) PATH=$PATH:$PWD/IncludesLinux/bin; export PATH ;;
esac

# Function to check if the user is root
is_user_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }

install_nv=0

# Parse command-line arguments
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      cat << EOF

RainbowMiner Nvidia CUDA Installer v1.1

Command-line options:
  -f, --force           Force (re-)install of the most current NVIDIA CUDA package
  -h, --help            Display this help page
EOF
      exit 0
      ;;
    -f|--force)
      install_nv=1
      ;;
    *)
      printf "Unknown option: %s\n" "$arg" >&2
      exit 1
      ;;
  esac
done

# Determine installation parameters
install_nv_params=""
[ "$install_nv" -eq 1 ] && install_nv_params="-f"

# Call the libnv.sh script
./IncludesLinux/bash/libnv.sh $install_nv_params
exit_code=$?

# Post-installation steps if root and installation succeeded
if [ "$exit_code" -eq 0 ] && is_user_root; then
  if [ ! -d "/opt/rainbowminer" ]; then
    mkdir -p /opt/rainbowminer
    if [ ! -d "/opt/rainbowminer/ocdcmd" ]; then
      mkdir -p /opt/rainbowminer/ocdcmd
      chmod 777 /opt/rainbowminer/ocdcmd
    fi
  fi

  # Copy library files
  find ./IncludesLinux/lib -type f -exec sh -c '
    target_dir="/opt/rainbowminer/$(dirname "${1#./IncludesLinux/}")"
    mkdir -p "$target_dir"
    cp -f "$1" "$target_dir"
  ' _ {} \;
fi

exit $exit_code
