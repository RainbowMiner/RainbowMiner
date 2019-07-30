#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& {./Install.ps1; exit \$lastexitcode}"

if ! [ -x "$(command -v pwsh)" ]; then
wget https://github.com/PowerShell/PowerShell/releases/download/v6.2.1/powershell-6.2.1-linux-x64.tar.gz -O /tmp/powershell.tar.gz
sudo mkdir -p /opt/microsoft/powershell/6
sudo tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/6
sudo chmod +x /opt/microsoft/powershell/6/pwsh
sudo ln -s /opt/microsoft/powershell/6/pwsh /usr/bin/pwsh
sudo rm -rf /tmp/powershell.tar.gz
fi

sudo pwsh -ExecutionPolicy bypass -Command ${command}
exitcode=$?
sudo chmod 777 -R $HOME/.local/share/powershell

if [ "$exitcode" == "10" ]; then
./start.sh
fi
