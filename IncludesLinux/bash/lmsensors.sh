#!/usr/bin/env bash

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [[ $PKG_MANAGER == *'pacman' ]]
 then
  sudo $PKG_MANAGER -S lm_sensors --noconfirm
elif [[ $PKG_MANAGER == *'yum' ]]
 then
  sudo $PKG_MANAGER install lm_sensors -y
 else
  sudo $PKG_MANAGER install lm-sensors -y
fi

sudo sensors-detect --auto
