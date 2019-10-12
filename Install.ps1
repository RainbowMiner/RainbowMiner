using module .\Include.psm1

Set-OsFlags

if ($MyInvocation.MyCommand.Path) {$Dir = (Split-Path $script:MyInvocation.MyCommand.Path);Set-Location $Dir}

if (-not (Test-IsElevated)) {
    Write-Host "Exiting without installation"
    Write-Host " "
    Write-Host "Please run the install script $(if ($IsWindows) {"with admin privileges"} else {"as root (use 'sudo ./install.sh')"})" -ForegroundColor Yellow    
    exit
}

if ($IsLinux) {
    if (-not $Dir) {$Dir = $Pwd}
    Get-ChildItem ".\*.sh" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    Get-ChildItem ".\IncludesLinux\bash\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}
    Get-ChildItem ".\IncludesLinux\bin\*" -File | Foreach-Object {try {& chmod +x "$($_.FullName)" > $null} catch {}}

    Write-Host "Install libc .."
    Start-Process ".\IncludesLinux\bash\libc.sh" -Wait
    Write-Host "Install libuv .."
    Start-Process ".\IncludesLinux\bash\libuv.sh" -Wait
    Write-Host "Install libcurl4 .."
    Start-Process ".\IncludesLinux\bash\libcurl4.sh" -Wait
    Write-Host "Install libopencl .."
    Start-Process ".\IncludesLinux\bash\libocl.sh" -Wait
    Write-Host "Install libjansson-dev .."
    Start-Process ".\IncludesLinux\bash\libjansson.sh" -Wait
    Write-Host "Install p7zip .."
    Start-Process ".\IncludesLinux\bash\p7zip.sh" -Wait
    Write-Host "Install screen .."
    Start-Process ".\IncludesLinux\bash\screen.sh" -Wait

    Write-Host "Linking libraries .."
    if ($Libs = Get-Content ".\IncludesLinux\libs.json" -Raw -ErrorAction Ignore | ConvertFrom-Json -ErrorAction Ignore) {
        $Libs.PSObject.Properties | Where-Object {Test-Path "/opt/rainbowminer/lib/$($_.Value)"} | Foreach-Object {
            Invoke-Exe -FilePath "ln" -ArgumentList "-nfs /opt/rainbowminer/lib/$($_.Value) /opt/rainbowminer/lib/$($_.Name)" > $null
        }
    }
    Remove-Variable "Libs"

    Invoke-Expression "lspci" | Select-String "VGA", "3D" | Tee-Object -Variable lspci | Tee-Object -FilePath ".\Data\gpu-count.txt" | Out-null
}

if ($IsWindows) {
    $EnvBits = if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}

    Write-Host "Install Microsoft Visual C++ 2013 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore

    Write-Host "Install Microsoft Visual C++ 2015/2017/2019 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://aka.ms/vs/16/release/vc_redist.$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore

    Invoke-Expression ".\Includes\pci\lspci.exe" | Select-String "VGA compatible controller" | Tee-Object -Variable lspci | Tee-Object -FilePath ".\Data\gpu-count.txt" | Out-Null
}

Write-Host "Detecting GPUs .."
$GNVIDIA = ($lspci -match "NVIDIA" -notmatch "nForce" | Measure-Object).Count
$GAMD    = ($lspci -match "Advanced Micro Devices" -notmatch "RS880" -notmatch "Stoney" | Measure-Object).Count

if ($GNVIDIA) {
    try {
        $data = @(Get-DeviceName "nvidia" -UseAfterburner $false | Select-Object)
        if (($data | Measure-Object).Count) {Set-ContentJson ".\Data\nvidia-names.json" -Data $data  > $null}
    } catch {
        Write-Host "WARNING: NVIDIA configuration could not be read." -ForegroundColor Yellow
    }
    if ($GNVIDIA -eq 1) {Write-Host " Nvidia GPU found."}
    else {Write-Host " $($GNVIDIA) Nvidia GPUs found."}
}
if ($GAMD) {
    try {
        $data = @(Get-DeviceName "amd" -UseAfterburner $($IsWindows -and $GAMD -lt 7) | Select-Object)
        if (($data | Measure-Object).Count) {Set-ContentJson ".\Data\amd-names.json" -Data $data > $null}
    } catch {
        Write-Host "WARNING: AMD configuration could not be read.$(if ($IsLinux) {" Please install rocm-smi!"})" -ForegroundColor Yellow
    }
    if ($GAMD -eq 1) {Write-Host " AMD GPU found."}
    else {Write-Host " $($GAMD) AMD GPUs found."}
}
if (-not $GNVIDIA -and -not $GAMD) {
    Write-Host " No GPUs found."
}

if ($IsLinux) {
    Get-ChildItem ".\Data" -Filter "*-names.json" -File -ErrorAction Ignore | Foreach-Object {& chmod a+rw "$($_.FullName)" > $null}
    Get-ChildItem ".\Data" -Filter "gpu-count.json" -File -ErrorAction Ignore | Foreach-Object {& chmod a+rw "$($_.FullName)" > $null}
}

if ($IsWindows -and $GNVIDIA) {
    $Install_NVSMI = $false
    if (-not (Test-Path "C:\Program Files\NVIDIA Corporation\NVSMI\nvml.dll")) {
        Write-Host "WARNING: nvml.dll is missing" -ForegroundColor Yellow
        $Install_NVSMI = $true
    }
    if (-not (Test-Path "C:\Program Files\NVIDIA Corporation\NVSMI\nvidia-smi.exe")) {
        Write-Host "WARNING: nvidia-smi.exe is missing" -ForegroundColor Yellow
        $Install_NVSMI = $true
    }

    if ($Install_NVSMI) {
        Write-Host "WARNING: RainbowMiner will try to install NVSMI, but the driver version may be wrong!" -ForegroundColor Yellow
        if (-not (Test-Path "C:\Program Files\NVIDIA Corporation")) { 
            Write-Host "ERROR: RainbowMiner failed to install NVSMI folder, no NVIDIA Corporation file found in C:\Program Files" -ForegroundColor Red
        } 
        else {
            try {
                $NVSMI_Path = "C:\Program Files\NVIDIA Corporation\NVSMI"
                if (-not (Test-Path $NVSMI_Path)) {New-Item $NVSMI_Path -ItemType "directory" > $null}
            
                Copy-Item ".\Includes\nvidia-smi.exe" -Destination $NVSMI_Path -Force
                Copy-Item ".\Includes\nvml.dll" -Destination $NVSMI_Path -Force

                Write-Host "NVSMI installed!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to install NVSMI" -ForeGroundColor Red
            }
        }
    }
}

Write-Host " "

Write-Host "Done! You are now ready to run Rainbowminer ($(if ($IsWindows) {"run Start.bat"} else {"run start.sh"}))" -ForegroundColor Green

if (Test-Path ".\IncludesLinux\linux.updated") {
    Get-ChildItem ".\IncludesLinux\linux.updated" -ErrorAction Ignore | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}
}