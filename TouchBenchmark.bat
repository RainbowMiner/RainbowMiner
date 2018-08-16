@echo off
cd /d %~dp0
set /p benchtouch= This process will touch all benchmarking data. Are you sure you want to continue? [Y/N] 
IF /I "%benchtouch%"=="Y" (
    pwsh -executionpolicy bypass -command "& {Get-ChildItem Stats\*_HashRate.txt | Foreach-Object {$_.LastWriteTime = Get-Date}}"
	ECHO Success. All benchmarking data has current date/time, now.
	PAUSE
)
