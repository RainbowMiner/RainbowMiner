#!/usr/bin/env bash

PKG_MANAGER=$( command -v yum || command -v apt-get || command -v pacman)
if [ $PKG_MANAGER == 'pacman' ]
 then
  sudo $PKG_MANAGER -S libc-ares2 --noconfirm
  sudo $PKG_MANAGER -S libuv1 --noconfirm
  sudo $PKG_MANAGER -S libcurl3 --noconfirm
 else
  sudo $PKG_MANAGER install libc-ares2 libuv1 libcurl3 -y
fi
