#!/usr/bin/env bash

arch=$(lscpu | grep Architecture | awk {'print $2'});
if [ "${arch}" == "aarch64" ]; then
  wget https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-arm64.tar.gz -O /tmp/powershell.tar.gz
  wget http://ports.ubuntu.com/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_arm64.deb
  sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_arm64.deb
  rm libssl1.1_1.1.0g-2ubuntu4_arm64.deb
fi
