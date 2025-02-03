#!/usr/bin/env bash

is_user_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }
SUDO="${SUDO:-$(is_user_root || echo sudo)}"

# Architecture and OS detection
arch=$(uname -m)
osname=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')

# libssl1.1 installation for ARM-based Ubuntu and Debian systems
if [ "$arch" = "aarch64" ] && { [ "$osname" = "Ubuntu" ] || [ "$osname" = "Debian GNU/Linux" ]; }; then
  URL="http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb"
  FILE="libssl1.1_1.1.0g-2ubuntu4_arm64.deb"
  wget "$URL"
  $SUDO dpkg -i "$FILE"
  rm -f "$FILE"
fi
