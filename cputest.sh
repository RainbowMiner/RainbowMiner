#!/usr/bin/env bash

cd "$(dirname "$0")"

case ":$PATH:" in
  *:$PWD/IncludesLinux/bin:*) ;;
  *) export PATH=$PATH:$PWD/IncludesLinux/bin ;;
esac

command="& ./Scripts/CPUtest.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

read -n 1 -s -r -p "Press any key to continue"
