#!/usr/bin/env bash

cd "$(dirname "$0")"

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

architecture="$(uname -m)"
case $architecture in
    i386|i686) architecture="i386" ;;
    x86_64) architecture="amd64" ;;
    arm|aarch64) dpkg --print-architecture | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
esac

if [[ $architecture == arm* ]]; then
    CMD=rbmtail-armv8
else
    CMD=rbmtail
fi

$CMD ./Logs rbm
