@cd /d %~dp0

@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& .\listdevices.ps1"

@echo off

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -command "%command%"
    goto end
)
pwsh -command "%command%"

:end

pause