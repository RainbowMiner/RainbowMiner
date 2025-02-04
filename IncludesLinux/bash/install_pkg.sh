#!/usr/bin/env bash

# Function to check if the user is root
is_user_root() { [ "$(id -u)" -eq 0 ]; }
SUDO="${SUDO:-$(is_user_root || echo sudo)}"

# Function to detect the package manager
detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt-get"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v yum >/dev/null 2>&1; then
    echo "yum"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v zypper >/dev/null 2>&1; then
    echo "zypper"
  elif command -v apk >/dev/null 2>&1; then
    echo "apk"
  else
    echo "Unsupported" >&2
    exit 1
  fi
}

PKG_MANAGER=$(detect_pkg_manager)

# Function to install packages with correct names per package manager
install_package() {
  COMMAND=$1
  PACKAGE_APT=$2
  PACKAGE_DNF=$3
  PACKAGE_PACMAN=$4
  PACKAGE_ZYPPER=$5
  PACKAGE_APK=$6

  # Special handling for 7z to ensure full support
  if [ "$COMMAND" = "7z" ] && command -v 7z >/dev/null 2>&1; then
    if 7z i | grep -q "Formats"; then
      echo "7z with full support already installed. Skipping."
      COMMAND=""  # Set COMMAND to empty to skip installation
    fi
  fi

  # Check if the command exists, skip installation if it does
  if [ -n "$COMMAND" ] && command -v "$COMMAND" >/dev/null 2>&1; then
    echo "$COMMAND already installed. Skipping."
    return
  fi

  case $PKG_MANAGER in
    apt-get)
      $SUDO apt-get install -y $PACKAGE_APT || true ;;
    dnf|yum)
      $SUDO $PKG_MANAGER install -y $PACKAGE_DNF || true ;;
    pacman)
      $SUDO pacman -S --noconfirm $PACKAGE_PACMAN || true ;;
    zypper)
      $SUDO zypper install -y $PACKAGE_ZYPPER || true ;;
    apk)
      $SUDO apk add $PACKAGE_APK || true ;;
    *)
      echo "Unsupported package manager." >&2
      exit 1 ;;
  esac
}

# Package installation (command, apt, dnf/yum, pacman, zypper, apk)
install_package "wget" "wget" "wget" "wget" "wget" "wget"
install_package "tar" "tar" "tar" "tar" "tar" "tar"
install_package "screen" "screen" "screen" "screen" "screen" "screen"
install_package "tmux" "tmux" "tmux" "tmux" "tmux" "tmux"
install_package "7z" "p7zip-full" "p7zip" "p7zip" "p7zip" "p7zip p7zip-plugins"
install_package "virt-what" "virt-what" "virt-what" "virt-what" "virt-what" "virt-what"

# Libraries (no direct command to check)
install_package "" "libc-ares2" "c-ares" "c-ares" "libc-ares2" "c-ares"
install_package "" "libuv1" "libuv" "libuv" "libuv1" "libuv"
install_package "" "libcurl4 libcurl4-openssl-dev" "libcurl libcurl-devel" "curl" "libcurl4" "curl"
install_package "" "libaprutil1" "apr-util" "apr-util" "libapr-util1" "apr-util"
install_package "" "ocl-icd-libopencl1" "ocl-icd" "ocl-icd" "ocl-icd" "ocl-icd"
install_package "" "libjansson4" "jansson" "jansson" "libjansson4" "jansson"
install_package "" "libltdl7" "libtool-ltdl" "libtool" "libltdl7" "libtool-ltdl"
install_package "" "libncurses5" "ncurses-libs" "ncurses" "ncurses5" "ncurses-libs"
install_package "" "libomp-dev" "libomp" "openmp" "libomp-devel" "libomp"

# Architecture and OS detection
arch=$(uname -m)
osname=$(grep '^NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')

# libssl1.1 installation for ARM-based Ubuntu and Debian systems
if [ "$arch" = "aarch64" ] && { [ "$osname" = "Ubuntu" ] || [ "$osname" = "Debian GNU/Linux" ]; }; then
  URL="https://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb"
  FILE="libssl1.1_1.1.0g-2ubuntu4_arm64.deb"

  # Set timeouts: 10 seconds to connect, 30 seconds max for the whole download
  wget --timeout=10 --tries=3 --waitretry=5 --read-timeout=30 -O "$FILE" "$URL"

  # Install only if the download was successful
  if [ -f "$FILE" ]; then
    $SUDO dpkg -i "$FILE"
    rm -f "$FILE"
  else
    echo "Download failed for $URL"
  fi
fi
