@echo off
cd /d %~dp0
set /p statreset= This process will remove all accumulated pool totals. Are you sure you want to continue? [Y/N] 
IF /I "%statreset%"=="Y" (
	if exist "Stats\Totals\*Total.txt" del "Stats\Totals\*Total.txt"
	ECHO Your totals have been successfully reset.
	PAUSE
)
