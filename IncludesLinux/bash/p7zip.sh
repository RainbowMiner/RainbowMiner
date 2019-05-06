#!/usr/bin/env bash

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [ $PKG_MANAGER == 'pacman' ]
 then
  sudo $PKG_MANAGER -S p7zip-full --noconfirm
 else
  sudo $PKG_MANAGER install p7zip-full -y
fi
