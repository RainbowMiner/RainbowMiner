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

version () { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }
is_user_root () { [ "${EUID:-$(id -u)}" -eq 0 ]; }

pwsh_major_version="7"
pwsh_minor_version="2"
pwsh_build_version="21"

pwsh_version="${pwsh_major_version}.${pwsh_minor_version}.${pwsh_build_version}"

if [ -x "$(command -v pwsh)" ]; then
  pwsh_version_current="$(pwsh --version | sed -nre 's/^[^0-9]*(([0-9]+\.)*[0-9]+).*/\1/p')"
fi

pwsh_update=false
install_as_root=false
install_as_user=false

for arg in "$@"
do
  if [ "$arg" == "--help" ] || [ "$arg" == "-h" ]; then
    cat << EOF

RainbowMiner Installer v2.0

Commandline options:

  -u, --user            install in user environment only
  -r, --root            force install as root (adds sudo to everything)
  -pv, --pwsh_version   shows version of currently installed powershell
  -pu, --pwsh_update    updates powershell to version ${pwsh_version}
  -h, --help            displays this help page

EOF
    exit
  elif [ "$arg" == "--pwsh_version" ] || [ "$arg" == "-pv" ]; then
    if [ "${pwsh_version_current}" != "" ]; then
      echo ${pwsh_version_current}
    else
      echo "Powershell not installed"
    fi
    exit
  elif [ "$arg" == "--user" ] || [ "$arg" == "-u" ]; then
    install_as_user=true
  elif [ "$arg" == "--root" ] || [ "$arg" == "-r" ]; then
    install_as_root=true
  elif [ "$arg" == "--pwsh_update" ] || [ "$arg" == "-pu" ]; then
    pwsh_update=true
  fi
done

if $install_as_root && $install_as_user; then
  echo "Parameters -u/--user and -r/--root cannot be used both"
  exit
fi

if $install_as_user && [ -L "/usr/bin/pwsh" ]; then
  echo "Already installed as root, parameter -u/--user not possible"
  install_as_user=false
  install_as_root=true
elif is_user_root && ! $install_as_user; then
  install_as_root=true
fi

if ! is_user_root && ! $install_as_root && ! $install_as_user; then
  cat << EOF

** The script has not been started as root. **

It is possible to install RainbowMiner and Microsoft Powershell in the local user environment but some miners might fail as a result of missing libraries, others might run slower than expected.

EOF
  read -p "Do you want to install in the user environment? Enter Y or N [default=N] " read_install_as_user
  if [ "$read_install_as_user" == "Y" ] || [ "$read_install_as_user" == "y" ]; then
    install_as_user=true
  else
    install_as_root=true
  fi
fi

SUDO=''
if $install_as_root; then
  if ! is_user_root; then
    SUDO="sudo"
  fi
  INSTALL_PATH="/opt"
  BINARY_PATH="/usr/bin/pwsh"
else
  INSTALL_PATH="$PWD"
  BINARY_PATH="$PWD/IncludesLinux/bin/pwsh"
fi

INSTALL_PATH="$INSTALL_PATH/microsoft/powershell/$pwsh_major_version"

if $pwsh_update; then
  if [ "${pwsh_version_current}" != "" ]; then
    if [ $(version ${pwsh_version_current}) -lt $(version ${pwsh_version}) ]; then
      if [ -L "$BINARY_PATH" ]; then
        $SUDO rm -f "$BINARY_PATH"
      fi
      printf "\nPowershell will be updated from ${pwsh_version_current} -> ${pwsh_version}\n\n"
    else
      printf "\nPowershell ${pwsh_version_current} already up to date\n\n"
    fi
  else
    printf "\nPowershell not installed, yet\n\n"
  fi
fi

if ! [ -x "$(command -v pwsh)" ]; then
  if ps -C pwsh >/dev/null
  then
    printf "Alas! RainbowMiner or another pwsh process is still running. Cannot update.\n\n"
  else
    if [ -L "$BINARY_PATH" ]; then
      $SUDO rm -f "$BINARY_PATH"
    fi
    if [ "${architecture}" == "arm64" ]; then
      wget https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-arm64.tar.gz -O "$PWD/powershell.tar.gz"
    elif [ "${architecture}" == "arm" ]; then
      wget https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-arm32.tar.gz -O "$PWD/powershell.tar.gz"
    else
      wget https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-x64.tar.gz -O "$PWD/powershell.tar.gz"
    fi

    $SUDO mkdir -p "$INSTALL_PATH"
    $SUDO tar zxf "$PWD/powershell.tar.gz" -C "$INSTALL_PATH" --overwrite
    $SUDO chmod +x "$INSTALL_PATH/pwsh"
    $SUDO ln -s "$INSTALL_PATH/pwsh" "$BINARY_PATH"
    $SUDO rm -f "$PWD/powershell.tar.gz"
  fi
fi

if [ "${pwsh_update}" == "1" ]; then
  exit
fi

$SUDO chmod +x ./IncludesLinux/bin/*

if $install_as_root; then
  if ! [ -d "/opt/rainbowminer" ]; then
    $SUDO mkdir -p /opt/rainbowminer
    if ! [ -d "/opt/rainbowminer/ocdcmd" ]; then
      $SUDO mkdir -p /opt/rainbowminer/ocdcmd
      $SUDO chmod 777 /opt/rainbowminer/ocdcmd
    fi
  fi

  $SUDO cp -Rf ./IncludesLinux/* /opt/rainbowminer
  $SUDO chmod +x /opt/rainbowminer/bin/ocdaemon
  $SUDO ln -nfs /opt/rainbowminer/bin/ocdaemon /usr/bin/ocdaemon
  $SUDO /opt/rainbowminer/bin/ocdaemon reinstall

  if ! [ -x "$(command -v amdmeminfo)" ]; then
    $SUDO ln -nfs /opt/rainbowminer/bin/amdmeminfo /usr/bin/amdmeminfo
  fi

  if ! [ -x "$(command -v wolfamdctrl)" ]; then
    $SUDO ln -nfs /opt/rainbowminer/bin/wolfamdctrl /usr/bin/wolfamdctrl
  fi

  if ! [ -x "$(command -v rbmtail)" ]; then
    $SUDO ln -nfs /opt/rainbowminer/bin/rbmtail /usr/bin/rbmtail
  fi
fi

if $install_as_root; then
  command="& {./Scripts/Install.ps1; exit \$lastexitcode}"
else
  command="& {./Scripts/Install.ps1 mode=user; exit \$lastexitcode}"
fi

$SUDO pwsh -ExecutionPolicy bypass -Command ${command}
exitcode=$?
$SUDO chmod 777 -R $HOME/.local/share/powershell

if [ "$exitcode" == "10" ]; then
  ./start.sh
fi
