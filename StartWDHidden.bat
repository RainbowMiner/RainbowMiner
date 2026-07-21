@cd /d %~dp0

@if not defined RBM_RUNCOPY (
    set "RBM_RUNCOPY=1"
    copy /y "%~f0" "%~dp0StartWDHidden.run.cmd" >nul 2>nul
    if exist "%~dp0StartWDHidden.run.cmd" (
        "%~dp0StartWDHidden.run.cmd"
        exit /b
    )
)

@if not "%GPU_FORCE_64BIT_PTR%"=="1" (setx GPU_FORCE_64BIT_PTR 1) > nul
@if not "%GPU_MAX_HEAP_SIZE%"=="100" (setx GPU_MAX_HEAP_SIZE 100) > nul
@if not "%GPU_USE_SYNC_OBJECTS%"=="1" (setx GPU_USE_SYNC_OBJECTS 1) > nul
@if not "%GPU_MAX_ALLOC_PERCENT%"=="100" (setx GPU_MAX_ALLOC_PERCENT 100) > nul
@if not "%GPU_SINGLE_ALLOC_PERCENT%"=="100" (setx GPU_SINGLE_ALLOC_PERCENT 100) > nul
@if not "%CUDA_DEVICE_ORDER%"=="PCI_BUS_ID" (setx CUDA_DEVICE_ORDER PCI_BUS_ID) > nul

@set "command=& {.\rainbowminer.ps1 -configfile .\Config\config.txt; exit $lastexitcode}"
@set "updater=& .\updater.ps1"
@set "RBM_STARTLOOP=1"

@echo off

rem start pwsh -noexit -executionpolicy bypass -command "& .\reader.ps1 -log '^(.+)?-\d+_\d\d\d\d-\d\d-\d\d_\d\d-\d\d-\d\d.txt' -sort '^[^_]*_' -quickstart"

rem watchdog: restarts pwsh after a crash, gives up after WD_FAILMAX consecutive runs shorter than WD_MINRUN seconds
if not defined WD_FAILMAX set "WD_FAILMAX=5"
if not defined WD_MINRUN set "WD_MINRUN=120"
set "WD_FAILCOUNT=0"

:restart
for /f %%i in ('powershell -noprofile -command "[int64]((Get-Date).ToUniversalTime()-[datetime]'1970-01-01').TotalSeconds"') do set "WD_START=%%i"

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -executionpolicy bypass -windowstyle hidden -command "%command%"
) else (
    pwsh -executionpolicy bypass -windowstyle hidden -command "%command%"
)
set "WD_CODE=%errorlevel%"

if not "%WD_CODE%"=="999" goto checkexit

where pwsh.exe >nul 2>nul
if %errorlevel%==1 (
    powershell -version 5.0 -executionpolicy bypass -command "%updater%"
) else (
    pwsh -executionpolicy bypass -command "%updater%"
)
set "WD_FAILCOUNT=0"
goto restart

:checkexit
rem intentional restart without update (exit 998)
if "%WD_CODE%"=="998" (set "WD_FAILCOUNT=0" & goto restart)

rem intentional exits: normal stop, Ctrl+C (0xC000013A), stopp.txt present
if "%WD_CODE%"=="0" goto end
if "%WD_CODE%"=="-1073741510" goto end
if exist "stopp.txt" goto end

rem unexpected exit -> watchdog path
for /f %%i in ('powershell -noprofile -command "[int64]((Get-Date).ToUniversalTime()-[datetime]'1970-01-01').TotalSeconds"') do set "WD_END=%%i"
set /a WD_RUNTIME=WD_END-WD_START

if %WD_RUNTIME% GEQ %WD_MINRUN% (set "WD_FAILCOUNT=0") else (set /a WD_FAILCOUNT+=1)
if not exist "Logs" mkdir "Logs"

if %WD_FAILCOUNT% GEQ %WD_FAILMAX% goto giveup

echo RainbowMiner exited unexpectedly with code %WD_CODE% after %WD_RUNTIME%s - restarting in 10 seconds
>> "Logs\watchdog.txt" echo %date% %time% watchdog: pwsh exit code %WD_CODE% after %WD_RUNTIME%s - restart [fails %WD_FAILCOUNT%/%WD_FAILMAX%]
ping -n 11 127.0.0.1 >nul
goto restart

:giveup
echo RainbowMiner crashed %WD_FAILCOUNT% times in a row within %WD_MINRUN%s each - giving up
>> "Logs\watchdog.txt" echo %date% %time% watchdog: giving up after %WD_FAILCOUNT% rapid crashes [last exit code %WD_CODE%]

:end
