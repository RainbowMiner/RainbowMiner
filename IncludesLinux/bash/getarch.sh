#!/usr/bin/env bash

architecture="$(uname -m)"
case $architecture in
    i386|i686) architecture="i386" ;;
    x86_64) architecture="amd64" ;;
    arm|aarch64) dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
esac

echo $architecture
