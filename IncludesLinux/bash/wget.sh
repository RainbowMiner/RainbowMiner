#!/usr/bin/env bash

# Function to check if the user is root
is_user_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }
SUDO="${SUDO:-$(is_user_root || echo sudo)}"

# Package to be installed
PACKAGE="wget"

# Detect the package manager
if command -v apt-get >/dev/null 2>&1; then
  PKG_MANAGER="apt-get"
  INSTALL_CMD="$SUDO $PKG_MANAGER install -y $PACKAGE"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MANAGER="dnf"
  INSTALL_CMD="$SUDO $PKG_MANAGER install -y $PACKAGE"
elif command -v yum >/dev/null 2>&1; then
  PKG_MANAGER="yum"
  INSTALL_CMD="$SUDO $PKG_MANAGER install -y $PACKAGE"
elif command -v pacman >/dev/null 2>&1; then
  PKG_MANAGER="pacman"
  INSTALL_CMD="$SUDO $PKG_MANAGER -S --noconfirm $PACKAGE"
elif command -v zypper >/dev/null 2>&1; then
  PKG_MANAGER="zypper"
  INSTALL_CMD="$SUDO $PKG_MANAGER install -y $PACKAGE"
elif command -v apk >/dev/null 2>&1; then
  PKG_MANAGER="apk"
  INSTALL_CMD="$SUDO $PKG_MANAGER add $PACKAGE"
else
  echo "Unsupported Linux distribution. No known package manager found." >&2
  exit 1
fi

# Install the package
echo "Installing $PACKAGE using $PKG_MANAGER..."
$INSTALL_CMD
