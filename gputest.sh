#!/usr/bin/env bash

command="& ./GPUtest.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

read -n 1 -s -r -p "Press any key to continue"
