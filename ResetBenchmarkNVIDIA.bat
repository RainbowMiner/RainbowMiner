@echo off
cd /d %~dp0
set /p benchreset= This process will remove all NVIDIA benchmarking data. Are you sure you want to continue? [Y/N] 
IF /I "%benchreset%"=="Y" (
	if exist "Stats\Miners\NVIDIA-*_HashRate.txt" del "Stats\Miners\NVIDIA-*_HashRate.txt"
	if exist "Stats\NVIDIA-*_HashRate.txt" del "Stats\NVIDIA-*_HashRate.txt"
	ECHO Success. RainbowMiner will rebenchmark all needed algorithm.
	PAUSE
)
