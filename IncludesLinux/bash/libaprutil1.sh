#!/usr/bin/env bash

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [[ $PKG_MANAGER == *'pacman' ]]
 then
  sudo $PKG_MANAGER -S libaprutil1 --noconfirm
 else
  sudo $PKG_MANAGER libaprutil1 -y
fi
