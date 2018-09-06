@echo off
cd /d %~dp0
set /p benchreset= This process will remove all AMD benchmarking data. Are you sure you want to continue? [Y/N] 
IF /I "%benchreset%"=="Y" (
	if exist "Stats\Miners\AMD-*_HashRate.txt" del "Stats\Miners\AMD-*_HashRate.txt"
	if exist "Stats\AMD-*_HashRate.txt" del "Stats\AMD-*_HashRate.txt"
	ECHO Success. RainbowMiner will rebenchmark all needed algorithm.
	PAUSE
)
