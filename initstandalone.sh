#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./InitStandalone.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

