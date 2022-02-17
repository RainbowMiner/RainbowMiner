#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./Scripts/ResetWorkers.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}
