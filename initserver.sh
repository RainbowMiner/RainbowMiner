#!/usr/bin/env bash

cd "$(dirname "$0")"

export GPU_FORCE_64BIT_PTR=1
export GPU_MAX_HEAP_SIZE=100
export GPU_USE_SYNC_OBJECTS=1
export GPU_MAX_ALLOC_PERCENT=100
export GPU_SINGLE_ALLOC_PERCENT=100
export GPU_MAX_WORKGROUP_SIZE=256
export CUDA_DEVICE_ORDER=PCI_BUS_ID

command="& ./InitServer.ps1"

pwsh -ExecutionPolicy bypass -Command ${command}

