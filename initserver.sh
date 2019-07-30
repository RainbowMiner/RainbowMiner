#!/usr/bin/env bash

cd "$(dirname "$0")"

command="& ./InitServer.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

