#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./GPUtest.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

read -n 1 -s -r -p "Press any key to continue"
