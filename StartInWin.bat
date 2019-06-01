@cd /d %~dp0

@if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
@if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
@if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
@if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
@if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& {.\rainbowminer.ps1 -configfile .\Config\config.txt; exit $lastexitcode}"
@set "updater=& .\updater.ps1"

@echo off

rem start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log '^(.+)?-\d+_\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d.txt' -sort '^[^_]*_' -quickstart"

:restart
where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -executionpolicy bypass -windowstyle normal -command "%command%"
    if %errorlevel%==999 (
        powershell -version 5.0 -executionpolicy bypass -command "%updater%"
        goto restart
    )
    goto end
)

pwsh -executionpolicy bypass -windowstyle normal -command "%command%"
if %errorlevel%==999 (
    pwsh -executionpolicy bypass -command "%updater%"
    goto restart
)

:end