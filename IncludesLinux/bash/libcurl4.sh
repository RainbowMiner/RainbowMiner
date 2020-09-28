#!/usr/bin/env bash

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [ $PKG_MANAGER == 'pacman' ]
 then
  sudo $PKG_MANAGER -S libcurl4 libcurl4-openssl-dev --noconfirm
 else
  sudo $PKG_MANAGER install libcurl4 libcurl4-openssl-dev -y
fi
