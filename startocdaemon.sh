#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./StartOCDaemon.ps1"

sudo pwsh -ExecutionPolicy bypass -Command ${command}
