#!/usr/bin/env bash

cd "$(dirname "$0")"

sudo bash -c "pwsh -ExecutionPolicy bypass -Command '& ./OCDaemon.ps1' &"
