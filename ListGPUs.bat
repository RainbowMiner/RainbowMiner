@echo off

cd /d %~dp0
if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

set "command=& .\listgpus.ps1"
pwsh -executionpolicy bypass -command "%command%"

pause