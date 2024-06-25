@cd /d %~dp0
@set "command=& .\Repair.ps1"
@echo off

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -executionpolicy bypass -windowstyle hidden -command "%command%"
    goto end
)

pwsh -executionpolicy bypass -windowstyle hidden -command "%command%"
:end
