using module ..\Modules\Include.psm1

Initialize-Session

Add-Type -Path .\DotNet\OpenCL\*.cs

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
    Write-Host "Install libltdl7 .."
    Start-Process ".\IncludesLinux\bash\libltdl7.sh" -Wait
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
    if ($Session.IsCore) {
        Import-Module NetSecurity -ErrorAction Ignore -SkipEditionCheck
        Import-Module Defender -ErrorAction Ignore -SkipEditionCheck
        Import-Module NetTCPIP -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore -SkipEditionCheck
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetTCPIP\NetTCPIP.psd1" -ErrorAction Ignore -SkipEditionCheck
    } else {
        Import-Module NetSecurity -ErrorAction Ignore
        Import-Module Defender -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
        Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore
    }

    if ((Get-Command "Get-MpPreference" -ErrorAction Ignore) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
        try {
            Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'$(if ($Session.IsCore) {" -SkipEditionCheck"}); Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs -WindowStyle Hidden
        } catch {
            Write-Host "WARNING: The RainbowMiner path ($(Convert-Path .)) could not be added to MS Defender's exclusion list. Please do this by hand!" -ForegroundColor Yellow
        }
    }

    Invoke-Expression ".\Includes\pci\lspci.exe" | Select-String "VGA compatible controller" | Tee-Object -Variable lspci | Tee-Object -FilePath ".\Data\gpu-count.txt" | Out-Null
}

Write-Host "Detecting GPUs .."
$GNVIDIA = ($lspci | Where-Object {$_ -match "NVIDIA" -and $_ -notmatch "nForce"} | Measure-Object).Count
$GAMD    = ($lspci | Where-Object {$_ -match "Advanced Micro Devices" -and $_ -notmatch "RS880" -and $_ -notmatch "Stoney"} | Measure-Object).Count

if ($GNVIDIA) {
    $NV_Version = ""
    try {
        $data = @(Get-DeviceName "nvidia" -UseAfterburner $false | Select-Object)
        if (($data | Measure-Object).Count) {
            Set-ContentJson ".\Data\nvidia-names.json" -Data $data  > $null
            $NV_Version = "$($data[0].DriverVersion)"
        }
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

    $NV_Install = @()

    $NV_Paths = [PSCustomObject]@{
        cur = "$(if (${env:ProgramFiles}) {${env:ProgramFiles}} else {"C:\Program Files"})\NVIDIA Corporation\NVSMI"
        win = Join-Path $env:windir "System32"
        inc = ".\Includes"
    }

    foreach ($NV_FileName in @("nvml.dll","nvidia-smi.exe")) {
        $NV_Data = [PSCustomObject]@{}

        $NV_Paths.PSObject.Properties.Name | Foreach-Object {
            $NV_Path = Join-Path $NV_Paths.$_ $NV_FileName
            $NV_Data | Add-Member $_ ([PSCustomObject]@{
                path    = $NV_Path
                version = "$(if (Test-Path $NV_Path) {"$((Get-Item $NV_Path).VersionInfo.FileVersion -replace "[^\d]+" -replace ‘.*?(?=.{1,5}$)’)"})"
            }) -Force
            if ($NV_Data.$_.version.Length -eq 5) {$NV_Data.$_.version = "$($NV_Data.$_.version.Substring(0,3)).$($NV_Data.$_.version.Substring(3,2))"}
        }

        $NV_File_Copy = if ((Test-Path $NV_Data.win.path) -and (-not $NV_Version -or $NV_Data.win.version -eq $NV_Version)) {$NV_Data.win} else {$NV_Data.inc}

        if (-not (Test-Path $NV_Data.cur.path)) {
            Write-Host "WARNING: $($NV_Data.cur.path) is missing" -ForegroundColor Yellow
            $NV_Install += [PSCustomObject]@{from = $NV_File_Copy; to = $NV_Data.cur}
        } elseif ($NV_Version -and $NV_Data.cur.version) {
            if ($NV_Data.cur.version -ne $NV_Version) {
                Write-Log -Level Warn "NVIDIA $($NV_Data.cur.path) has wrong version $($NV_Data.cur.version) vs. $NV_Version"
                if ($NV_File_Copy.version -ne $NV_Data.cur.version) {
                    $NV_Install += [PSCustomObject]@{from = $NV_File_Copy; to = $NV_Data.cur}
                }
            }
        }
    }
    if ($NV_Install) {
        Write-Host "WARNING: RainbowMiner will try to install NVSMI, but the driver version may be wrong!" -ForegroundColor Yellow
        try {
            if (-not (Test-Path $NV_Paths.cur)) {New-Item $NV_Paths.cur -ItemType "directory" > $null}

            foreach($NV_Fx in $NV_Install) {
                Copy-Item $NV_Fx.from.path -Destination $NV_Fx.to.path -Force
            }

            Write-Host "NVSMI installed successfully!" -ForegroundColor Green
            $Install_NVSMI = $false
        } catch {
            Write-Host "Failed to install NVSMI" -ForeGroundColor Red
        }
    }
}

Write-Host " "

if ($IsWindows) {
    $EnvBits = if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}

    Write-Host "Checking for Microsoft Visual C++ Runtimes."
    Write-Host " "
    Write-Host "It is possible, that your PC will be automatically rebooted, after these installs. RainbowMiner will be ready to go, after such an reboot!" -BackgroundColor Yellow -ForegroundColor Black
    Write-Host " "

    Write-Host "Check/Install Microsoft Visual C++ 2013 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore

    Write-Host "Check/Install Microsoft Visual C++ 2015/2017/2019 .."
    if (-not (Test-IsElevated)) {Write-Host "Please watch for UAC popups and confirm them!" -ForegroundColor Yellow}
    Expand-WebRequest "https://aka.ms/vs/16/release/vc_redist.$($EnvBits).exe" -ArgumentList "/q" -ErrorAction Ignore
}

Write-Host "Done! You are now ready to run Rainbowminer ($(if ($IsWindows) {"run Start.bat"} else {"run start.sh"}))" -ForegroundColor Green

if (Test-Path ".\IncludesLinux\linux.updated") {
    Get-ChildItem ".\IncludesLinux\linux.updated" -ErrorAction Ignore | Foreach-Object {Remove-Item $_.FullName -Force -ErrorAction Ignore}
}