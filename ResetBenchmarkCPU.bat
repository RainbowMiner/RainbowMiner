@echo off
cd /d %~dp0
set /p benchreset= This process will remove all CPU benchmarking data. Are you sure you want to continue? [Y/N] 
IF /I "%benchreset%"=="Y" (
	if exist "Stats\Miners\CPU-*_HashRate.txt" del "Stats\Miners\CPU-*_HashRate.txt"
	if exist "Stats\CPU-*_HashRate.txt" del "Stats\CPU-*_HashRate.txt"
	ECHO Success. RainbowMiner will rebenchmark all needed algorithm.
	PAUSE
)
