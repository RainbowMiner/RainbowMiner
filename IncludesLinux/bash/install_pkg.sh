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
  PACKAGE_APT=$1
  PACKAGE_DNF=$2
  PACKAGE_PACMAN=$3
  PACKAGE_ZYPPER=$4
  PACKAGE_APK=$5

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

# Package installation
install_package "wget" "wget" "wget" "wget" "wget"
install_package "tar" "tar" "tar" "tar" "tar"
install_package "screen" "screen" "screen" "screen" "screen"
install_package "tmux" "tmux" "tmux" "tmux" "tmux"
install_package "p7zip-full" "p7zip" "p7zip" "p7zip" "p7zip p7zip-plugins"
install_package "libc-ares2" "c-ares" "c-ares" "libc-ares2" "c-ares"
install_package "libuv1" "libuv" "libuv" "libuv1" "libuv"
install_package "libcurl4 libcurl4-openssl-dev" "libcurl libcurl-devel" "curl" "libcurl4" "curl"
install_package "libaprutil1" "apr-util" "apr-util" "libapr-util1" "apr-util"
install_package "ocl-icd-libopencl1" "ocl-icd" "ocl-icd" "ocl-icd" "ocl-icd"
install_package "libjansson4" "jansson" "jansson" "libjansson4" "jansson"
install_package "libltdl7" "libtool-ltdl" "libtool" "libltdl7" "libtool-ltdl"
install_package "libncurses5" "ncurses-libs" "ncurses" "ncurses5" "ncurses-libs"
install_package "virt-what" "virt-what" "virt-what" "virt-what" "virt-what"
install_package "libomp-dev" "libomp" "openmp" "libomp-devel" "libomp"
#install_package "lm-sensors" "lm_sensors" "lm_sensors" "lm_sensors" "lm_sensors"
#install_package "libcurl3" "libcurl" "libcurl-compat" "libcurl3" "libcurl"

#$SUDO sensors-detect --auto

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
