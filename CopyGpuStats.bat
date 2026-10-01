@cd /d %~dp0

@set "command=& .\Scripts\CopyGpuStats.ps1"

@echo off

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -executionpolicy Bypass -command "%command%"
    goto end
)
pwsh -executionpolicy Bypass -command "%command%"

:end

pause
