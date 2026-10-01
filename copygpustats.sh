#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./Scripts/CopyGpuStats.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}
