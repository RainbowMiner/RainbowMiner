@echo off
cd /d %~dp0
setlocal

rem FixConsole.bat - set the default terminal application of the current Windows user
rem
rem Windows 11 hosts every console window in Windows Terminal by default. Windows
rem Terminal has known problems with classic console applications: the RainbowMiner
rem window may ignore move, close or minimize and the -windowstyle of the start
rem scripts is not applied reliably. This script switches the default back to the
rem classic Windows Console Host (conhost).
rem
rem Only needed, if RainbowMiner is started with Start.bat, StartHidden.bat or
rem StartInWin.bat. The watchdog start scripts StartWD.bat, StartWDHidden.bat and
rem StartWDInWin.bat detect Windows 11 and relaunch themselves under the classic
rem console host, on their own.
rem
rem Only the current user is affected, no administrator rights are needed.
rem
rem usage: FixConsole.bat [/f] [/r]
rem
rem   /f, /force     force, do not ask for confirmation
rem   /r, /restore   undo, set the default terminal back to "Let Windows decide"
rem   /h, /help, /?  show help

set "RBMRC=0"
set "RBMKEY=HKCU\Console\%%%%Startup"
set "RBMCONHOST={B23D10C0-E52E-411E-9D5B-C09FDF709C7D}"
set "RBMDEFAULT={00000000-0000-0000-0000-000000000000}"
set "RBMWTCON={2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}"
set "RBMWTTRM={E12CFF52-A866-4C77-9A90-F570A7AA2C6B}"
set "RBMFORCE=0"
set "RBMRESTORE=0"

:getargs
if "%~1"=="" goto argsdone
if /i "%~1"=="/f" (set "RBMFORCE=1"& shift& goto getargs)
if /i "%~1"=="/force" (set "RBMFORCE=1"& shift& goto getargs)
if /i "%~1"=="/r" (set "RBMRESTORE=1"& shift& goto getargs)
if /i "%~1"=="/restore" (set "RBMRESTORE=1"& shift& goto getargs)
if /i "%~1"=="/?" goto usage
if /i "%~1"=="/h" goto usage
if /i "%~1"=="/help" goto usage
echo.
echo FixConsole: unknown parameter "%~1"
set "RBMRC=1"
goto usage
:argsdone

set "RBMTARGET=%RBMCONHOST%"
set "RBMNAME=Windows Console Host"
if "%RBMRESTORE%"=="1" set "RBMTARGET=%RBMDEFAULT%"
if "%RBMRESTORE%"=="1" set "RBMNAME=Let Windows decide"

rem read the windows build number the locale safe way
set "RBMBUILD=0"
for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| find "CurrentBuildNumber"') do set "RBMBUILD=%%i"

echo.
echo RainbowMiner - default terminal application of the current user
echo Registry key: %RBMKEY%
echo.
echo Needed for Start.bat, StartHidden.bat and StartInWin.bat. The watchdog start
echo scripts StartWD.bat, StartWDHidden.bat and StartWDInWin.bat handle Windows 11
echo on their own.
echo.
if %RBMBUILD% GEQ 22000 (
    echo Windows build %RBMBUILD% detected: this is Windows 11 and hosts all console
    echo windows in Windows Terminal by default.
) else (
    echo Windows build %RBMBUILD% detected: the default terminal application is a
    echo Windows 11 feature and usually has no effect on this system.
)

rem read the current setting, missing values mean "Let Windows decide"
set "RBMCUR="
for /f "tokens=2*" %%a in ('reg query "%RBMKEY%" /v DelegationConsole 2^>nul ^| find /i "DelegationConsole"') do set "RBMCUR=%%b"

set "RBMCURNAME="
if not defined RBMCUR set "RBMCURNAME=not set, Let Windows decide"
if /i "%RBMCUR%"=="%RBMCONHOST%" set "RBMCURNAME=Windows Console Host"
if /i "%RBMCUR%"=="%RBMDEFAULT%" set "RBMCURNAME=Let Windows decide"
if /i "%RBMCUR%"=="%RBMWTCON%" set "RBMCURNAME=Windows Terminal"
if /i "%RBMCUR%"=="%RBMWTTRM%" set "RBMCURNAME=Windows Terminal"
if not defined RBMCURNAME set "RBMCURNAME=unknown %RBMCUR%"

echo.
echo Current setting: %RBMCURNAME%
echo New setting:     %RBMNAME%

if /i "%RBMCUR%"=="%RBMTARGET%" goto alreadyset
if "%RBMRESTORE%"=="1" if not defined RBMCUR goto alreadyset

if "%RBMFORCE%"=="1" goto apply

echo.
if "%RBMRESTORE%"=="1" goto askrestore
set /p RBMANSWER= This process will set the default terminal application of your Windows user to the classic Windows Console Host. Are you sure you want to continue? [Y/N] 
goto asked
:askrestore
set /p RBMANSWER= This process will set the default terminal application of your Windows user back to Let Windows decide. Are you sure you want to continue? [Y/N] 
:asked
if /i not "%RBMANSWER%"=="Y" goto cancelled

:apply
reg add "%RBMKEY%" /v DelegationConsole /t REG_SZ /d "%RBMTARGET%" /f >nul 2>nul
if errorlevel 1 goto failed
reg add "%RBMKEY%" /v DelegationTerminal /t REG_SZ /d "%RBMTARGET%" /f >nul 2>nul
if errorlevel 1 goto failed

echo.
echo The default terminal application has been set to: %RBMNAME%
echo.
echo This affects console windows that are opened from now on, only. Please stop and
echo restart RainbowMiner, to make the change take effect.
if "%RBMRESTORE%"=="0" echo To undo this change, run "FixConsole.bat /r" or set Settings -^> System -^> For developers -^> Terminal back to "Let Windows decide".
goto end

:alreadyset
echo.
echo The default terminal application is already set to "%RBMNAME%", nothing to do.
goto end

:cancelled
echo.
echo Cancelled, nothing has been changed.
goto end

:failed
echo.
echo FixConsole: the registry could not be written.
echo Please set Settings -^> System -^> For developers -^> Terminal to "%RBMNAME%" by hand.
set "RBMRC=1"
goto end

:usage
echo.
echo usage: FixConsole.bat [/f] [/r]
echo.
echo   Switches the default terminal application of the current Windows user to the
echo   classic Windows Console Host. Windows 11 uses Windows Terminal by default,
echo   which breaks RainbowMiner's console window (move, close, minimize and the
echo   -windowstyle of the start scripts).
echo.
echo   Only needed for Start.bat, StartHidden.bat and StartInWin.bat. The watchdog
echo   start scripts StartWD.bat, StartWDHidden.bat and StartWDInWin.bat handle
echo   Windows 11 on their own.
echo.
echo   /f or /force     force, do not ask for confirmation
echo   /r or /restore   undo, set the default terminal back to "Let Windows decide"
echo   /h or /help      show this help
echo.
endlocal & exit /b %RBMRC%

:end
echo.
if "%RBMFORCE%"=="0" pause
endlocal & exit /b %RBMRC%
