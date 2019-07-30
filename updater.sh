#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./Updater.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}
