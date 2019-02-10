@cd /d %~dp0

@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& .\listdevices.ps1"

@echo off

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -windowstyle maximized -executionpolicy Bypass -command "%command%"
    goto end
)
pwsh -windowstyle maximized -executionpolicy Bypass -command "%command%"

:end

pause