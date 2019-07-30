#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./InitClient.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

