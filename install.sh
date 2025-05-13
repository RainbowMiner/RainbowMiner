#!/usr/bin/env bash

cd "$(dirname "$0")"

# Add IncludesLinux/bin to PATH if not already present
case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) PATH=$PATH:$PWD/IncludesLinux/bin; export PATH ;;
esac

# Detect architecture
architecture="$(uname -m)"
case $architecture in
    i386|i686) architecture="i386" ;;
    x86_64) architecture="amd64" ;;
    arm|aarch64) dpkg --print-architecture 2>/dev/null | grep -q "arm64" && architecture="arm64" || architecture="arm" ;;
esac

# Functions
version() { echo "$1" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }
is_user_root() { [ "$(id -u)" -eq 0 ]; }

# Powershell version
pwsh_major_version="7"
pwsh_minor_version="2"
pwsh_build_version="24"

pwsh_version="${pwsh_major_version}.${pwsh_minor_version}.${pwsh_build_version}"

# Check current pwsh version
if command -v pwsh >/dev/null 2>&1; then
  pwsh_version_current="$(pwsh --version | sed -n 's/^[^0-9]*\([0-9.]*\).*/\1/p')"
fi

# Flags
pwsh_update=false
install_as_root=false
install_as_user=false
install_nv=false
uninstall_rbm=false
uninstall_pwsh=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      cat << EOF

RainbowMiner Installer v2.6

Options:
  -u, --user          Install in user environment only
  -r, --root          Force install as root
  -pv, --pwsh_version Show installed PowerShell version
  -pu, --pwsh_update  Update PowerShell to version ${pwsh_version}
  -nv                 Install/update NVIDIA CUDA
  -x, --uninstall     Uninstall RainbowMiner and leave PowerShell untouched
  -xx, --uninstallall Uninstall RainbowMiner and PowerShell
  -h, --help          Display this help page
EOF
      exit ;;
    -pv|--pwsh_version)
      echo "${pwsh_version_current:-Powershell not installed}"
      exit ;;
    -u|--user) install_as_user=true ;;
    -r|--root) install_as_root=true ;;
    -pu|--pwsh_update) pwsh_update=true ;;
    -nv) install_nv=true ;;
    -x|--uninstall) uninstall_rbm=true ;;
    -xx|--uninstallall)
      uninstall_rbm=true
      uninstall_pwsh=true ;;
  esac
done

# Uninstall first
if [ "$uninstall_rbm" = true ]; then

  printf "Really uninstall RainbowMiner and optionally PowerShell? Enter Y or N [default=N]: "
  read read_uninstall
  if [ "$read_uninstall" != "Y" ] && [ "$read_uninstall" != "y" ]; then
    echo "Aborted."
    exit 1
  fi

  if ! is_user_root; then
    SUDO="sudo"
  fi

  if [ "$uninstall_pwsh" = true ]; then
    echo "Uninstalling PowerShell .."
    INSTALL_PATH="/opt/microsoft/powershell/$pwsh_major_version"
    BINARY_PATH="/usr/bin/pwsh"
    [ -L "$BINARY_PATH" ] && $SUDO rm -f "$BINARY_PATH"
    [ -d "$INSTALL_PATH" ] && $SUDO rm -rf "$INSTALL_PATH"
  fi

  echo "Uninstalling RainbowMiner .."
  INSTALL_PATH="/opt/rainbowminer"
  OCDAEMON_PATH="$INSTALL_PATH/bin/ocdaemon"
  if [ -d "$INSTALL_PATH" ]; then
    $SUDO $OCDAEMON_PATH stop
    $SUDO $OCDAEMON_PATH uninstall
    for cmd in amdmeminfo wolfamdctrl rbmtail; do
      if [ -L "/usr/bin/$cmd" ]; then
        $SUDO rm -f "/usr/bin/$cmd"
      fi
    done

    $SUDO rm -rf "$INSTALL_PATH"
  fi

  for item in "$PWD"/* "$PWD"/.*; do
    case "$(basename "$item")" in
      install.sh|.|..) continue ;;
      *) $SUDO rm -rf "$item" ;;
    esac
  done

  echo "RainbowMiner has been uninstalled."
  echo "You may now delete the installation folder manually: $PWD"

  exit 0
fi

# Conflict check
if [ "$install_as_root" = true ] && [ "$install_as_user" = true ]; then
  echo "Error: Cannot use both -u/--user and -r/--root options."
  exit 1
fi

if [ "$install_as_user" = true ] && [ -L "/usr/bin/pwsh" ]; then
  echo "Already installed as root, parameter -u/--user not possible"
  install_as_user=false
  install_as_root=true
elif is_user_root && [ "$install_as_user" != true ]; then
  install_as_root=true
fi

if ! is_user_root && [ "$install_as_root" != true ] && [ "$install_as_user" != true ]; then
  cat << EOF

** The script has not been started as root. **

It is possible to install RainbowMiner and Microsoft Powershell in the local user environment but some miners might fail as a result of missing libraries, others might run slower than expected.
EOF
  printf "Do you want to install in the user environment? Enter Y or N [default=N]: "
  read read_install_as_user
  if [ "$read_install_as_user" = "Y" ] || [ "$read_install_as_user" = "y" ]; then
    install_as_user=true
  else
    install_as_root=true
  fi
fi

SUDO=''
if [ "$install_as_root" = true ]; then
  if ! is_user_root; then
    SUDO="sudo"
  fi
  INSTALL_PATH="/opt"
  BINARY_PATH="/usr/bin/pwsh"
else
  INSTALL_PATH="$PWD"
  BINARY_PATH="$PWD/IncludesLinux/bin/pwsh"
fi

export SUDO

$SUDO chmod +x ./IncludesLinux/bin/*
$SUDO chmod +x ./IncludesLinux/bash/*

if [ "$install_as_root" = true ]; then
  ./IncludesLinux/bash/install_pkg.sh
fi

INSTALL_PATH="$INSTALL_PATH/microsoft/powershell/$pwsh_major_version"

if [ "$pwsh_update" = true ]; then
  if [ -n "$pwsh_version_current" ]; then
    if [ "$(version "$pwsh_version_current")" -lt "$(version "$pwsh_version")" ]; then
      if [ -L "$BINARY_PATH" ]; then
        $SUDO rm -f "$BINARY_PATH"
      fi
      printf "\nPowershell will be updated from %s -> %s\n\n" "$pwsh_version_current" "$pwsh_version"
    else
      printf "\nPowershell %s already up to date\n\n" "$pwsh_version_current"
    fi
  else
    printf "\nPowershell not installed, yet\n\n"
  fi
fi

if ! command -v pwsh >/dev/null 2>&1; then
  if pgrep pwsh >/dev/null 2>&1; then
    printf "Alas! RainbowMiner or another pwsh process is still running. Cannot update.\n\n"
  else
    if [ -L "$BINARY_PATH" ]; then
      $SUDO rm -f "$BINARY_PATH"
    fi

    case "$architecture" in
      arm64) wget "https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-arm64.tar.gz" -O "$PWD/powershell.tar.gz" ;;
      arm) wget "https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-arm32.tar.gz" -O "$PWD/powershell.tar.gz" ;;
      *) wget "https://github.com/PowerShell/PowerShell/releases/download/v${pwsh_version}/powershell-${pwsh_version}-linux-x64.tar.gz" -O "$PWD/powershell.tar.gz" ;;
    esac

    $SUDO mkdir -p "$INSTALL_PATH"
    $SUDO tar zxf "$PWD/powershell.tar.gz" -C "$INSTALL_PATH" --overwrite
    $SUDO chmod +x "$INSTALL_PATH/pwsh"
    $SUDO ln -s "$INSTALL_PATH/pwsh" "$BINARY_PATH"
    $SUDO rm -f "$PWD/powershell.tar.gz"
  fi
fi

if [ "$pwsh_update" = "1" ]; then
  exit
fi

if [ "$install_nv" = true ]; then
  install_nv_params="-f"
else
  install_nv_params=""
fi

./IncludesLinux/bash/libnv.sh $install_nv_params

if [ "$install_as_root" = true ]; then
  if [ ! -d "/opt/rainbowminer" ]; then
    $SUDO mkdir -p /opt/rainbowminer
    if [ ! -d "/opt/rainbowminer/ocdcmd" ]; then
      $SUDO mkdir -p /opt/rainbowminer/ocdcmd
      $SUDO chmod 777 /opt/rainbowminer/ocdcmd
    fi
  fi

  $SUDO find ./IncludesLinux/ -type f -exec sh -c 'mkdir -p "/opt/rainbowminer/$(dirname "${1#./IncludesLinux/}")" && cp -f "$1" "/opt/rainbowminer/${1#./IncludesLinux/}"' _ {} \;
  $SUDO chmod +x /opt/rainbowminer/bin/ocdaemon
  $SUDO ln -nfs /opt/rainbowminer/bin/ocdaemon /usr/bin/ocdaemon
  $SUDO /opt/rainbowminer/bin/ocdaemon reinstall

  for cmd in amdmeminfo wolfamdctrl rbmtail; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      $SUDO ln -nfs "/opt/rainbowminer/bin/$cmd" "/usr/bin/$cmd"
    fi
  done
fi

if [ "$install_as_root" = true ]; then
  command="& {./Scripts/Install.ps1; exit \$lastexitcode}"
else
  command="& {./Scripts/Install.ps1 mode=user; exit \$lastexitcode}"
fi

$SUDO pwsh -ExecutionPolicy bypass -Command "$command"
exitcode=$?
$SUDO chmod 777 -R "$HOME/.local/share/powershell"

if [ "$exitcode" = "10" ]; then
  ./start.sh
fi
