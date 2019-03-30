@echo off
echo ... Set DPS service start type to manual ...
echo.
sc config DPS start= demand

echo.
echo ... Find PID of DPS service ...

for /f "tokens=2 delims=[:]" %%f in ('sc queryex dps ^|find /i "PID"') do set PID=%%f

echo.
echo ... Kill DPS service
echo.

taskkill /f /pid %PID%


echo.
echo ... Delete sru Folder ...
echo.

rd /s "%windir%\system32\sru"

echo.
echo ... Set DPS service start type to auto ...
echo.
sc config DPS start= auto

echo.
echo ... Start DPS service ...

sc start DPS
echo.

pause