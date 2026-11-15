#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./Scripts/RenumberGpuStats.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}
