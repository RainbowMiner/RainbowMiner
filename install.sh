#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& {./Install.ps1; exit \$lastexitcode}"

if ! [ -x "$(command -v pwsh)" ]; then
wget https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/powershell-6.2.2-linux-x64.tar.gz -O /tmp/powershell.tar.gz
sudo mkdir -p /opt/microsoft/powershell/6
sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/6
sudo chmod +x /opt/microsoft/powershell/6/pwsh
sudo ln -s /opt/microsoft/powershell/6/pwsh /usr/bin/pwsh
sudo rm -rf /tmp/powershell.tar.gz
fi

if ! [ -x "$(command -v startocdaemon)" ]; then
sudo mkdir -p /opt/rainbowminer
sudo mkdir -p /opt/rainbowminer/ocdcmd
sudo chmod 777 /opt/rainbowminer/ocdcmd
fi

sudo chmod +x ./IncludesLinux/bin/*
sudo cp -Rf ./IncludesLinux/* /opt/rainbowminer
sudo chmod +x /opt/rainbowminer/ocd/startocdaemon
sudo chmod +x /opt/rainbowminer/ocd/ocdaemon
sudo ln -nfs /opt/rainbowminer/ocd/startocdaemon /usr/bin/startocdaemon
sudo ln -nfs /opt/rainbowminer/ocd/ocdaemon /usr/bin/ocdaemon

if ! [ -x "$(command -v amdmeminfo)" ]; then
sudo ln -nfs /opt/rainbowminer/bin/amdmeminfo /usr/bin/amdmeminfo
fi

if ! [ -x "$(command -v wolfamdctrl)" ]; then
sudo ln -nfs /opt/rainbowminer/bin/wolfamdctrl /usr/bin/wolfamdctrl
fi

sudo pwsh -ExecutionPolicy bypass -Command ${command}
exitcode=$?
sudo chmod 777 -R $HOME/.local/share/powershell

if [ "$exitcode" == "10" ]; then
./start.sh
fi
