using module .\Include.psm1

Set-OsFlags

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

if (-not (Test-IsElevated)) {
    Write-Host "Exiting without installation"
    Write-Host " "
    Write-Host "Please run the install script $(if ($IsWindows) {"with admin privileges"} else {"as root (use 'sudo install.sh')"})" -ForegroundColor Yellow    
    exit
}

if ($IsLinux) {
    Write-Host "Set attributes .."
    Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    Write-Host "Install libc .."
    Start-Process ".\IncludesLinux\bash\libc.sh" -Wait
    Write-Host "Install libuv .."
    Start-Process ".\IncludesLinux\bash\libuv.sh" -Wait
    Write-Host "Install libcurl3 .."
    Start-Process ".\IncludesLinux\bash\libcurl3.sh" -Wait
    Write-Host "Install libopencl .."
    Start-Process ".\IncludesLinux\bash\libocl.sh" -Wait
    Write-Host "Install p7zip .."
    Start-Process ".\IncludesLinux\bash\p7zip.sh" -Wait
}

if ($IsWindows) {
    $EnvBits = if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}

    Write-Host "Install Microsoft Visual C++ 2013 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore

    Write-Host "Install Microsoft Visual C++ 2017 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://aka.ms/vs/15/release/vc_redist.$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore
}

Write-Host "Done! You are now ready to run Rainbowminer ($(if ($IsWindows) {"run Start.bat"} else {"run start.sh"}))" -ForegroundColor Green
