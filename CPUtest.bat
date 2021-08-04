@cd /d %~dp0

@set "command=& .\Scripts\CPUtest.ps1"

@echo off

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -windowstyle normal -executionpolicy Bypass -command "%command%"
    goto end
)
pwsh -windowstyle normal -executionpolicy Bypass -command "%command%"

:end

pause