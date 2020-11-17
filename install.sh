#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& {./Scripts/Install.ps1; exit \$lastexitcode}"

function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

if [ -x "$(command -v pwsh)" ]; then
  pwsh_version="$(pwsh --version | sed -nre 's/^[^0-9]*(([0-9]+\.)*[0-9]+).*/\1/p')"
  if [ $(version ${pwsh_version}) -lt $(version "7.1.0") ]; then
    sudo rm -f /usr/bin/pwsh
  fi
fi

if ! [ -x "$(command -v pwsh)" ]; then
  wget https://github.com/PowerShell/PowerShell/releases/download/v7.1.0/powershell-7.1.0-linux-x64.tar.gz -O /tmp/powershell.tar.gz
  sudo mkdir -p /opt/microsoft/powershell/7
  sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 --overwrite
  sudo chmod +x /opt/microsoft/powershell/7/pwsh
  sudo ln -s /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
  sudo rm -rf /tmp/powershell.tar.gz
fi


if ! [ -d "/opt/rainbowminer" ]; then
  sudo mkdir -p /opt/rainbowminer
  if ! [ -d "/opt/rainbowminer/ocdcmd" ]; then
    sudo mkdir -p /opt/rainbowminer/ocdcmd
    sudo chmod 777 /opt/rainbowminer/ocdcmd
  fi
fi

sudo chmod +x ./IncludesLinux/bin/*
sudo cp -Rf ./IncludesLinux/* /opt/rainbowminer
sudo chmod +x /opt/rainbowminer/bin/ocdaemon
sudo ln -nfs /opt/rainbowminer/bin/ocdaemon /usr/bin/ocdaemon
sudo /opt/rainbowminer/bin/ocdaemon reinstall

if ! [ -x "$(command -v amdmeminfo)" ]; then
  sudo ln -nfs /opt/rainbowminer/bin/amdmeminfo /usr/bin/amdmeminfo
fi

if ! [ -x "$(command -v wolfamdctrl)" ]; then
  sudo ln -nfs /opt/rainbowminer/bin/wolfamdctrl /usr/bin/wolfamdctrl
fi

if ! [ -x "$(command -v rbmtail)" ]; then
  sudo ln -nfs /opt/rainbowminer/bin/rbmtail /usr/bin/rbmtail
fi

sudo pwsh -ExecutionPolicy bypass -Command ${command}
exitcode=$?
sudo chmod 777 -R $HOME/.local/share/powershell

if [ "$exitcode" == "10" ]; then
  ./start.sh
fi
