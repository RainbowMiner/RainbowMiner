#!/usr/bin/env bash

is_user_root() { [ "${EUID:-$(id -u)}" -eq 0 ]; }
SUDO="${SUDO:-$(is_user_root || echo sudo)}"

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [[ $PKG_MANAGER == *'pacman' ]]
 then
  $SUDO $PKG_MANAGER -S lm_sensors --noconfirm
elif [[ $PKG_MANAGER == *'yum' ]]
 then
  $SUDO $PKG_MANAGER install lm_sensors -y
 else
  $SUDO $PKG_MANAGER install lm-sensors -y
fi

$SUDO sensors-detect --auto
