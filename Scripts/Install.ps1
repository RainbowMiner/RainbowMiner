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
    Write-Host "Install libaprutil1 .."
    Start-Process ".\IncludesLinux\bash\libaprutil1.sh" -Wait
    Write-Host "Install libopencl .."
    Start-Process ".\IncludesLinux\bash\libocl.sh" -Wait
    Write-Host "Install libjansson-dev .."
    Start-Process ".\IncludesLinux\bash\libjansson.sh" -Wait
    Write-Host "Install libltdl7 .."
    Start-Process ".\IncludesLinux\bash\libltdl7.sh" -Wait
    Write-Host "Install libncurses5 .."
    Start-Process ".\IncludesLinux\bash\libncurses5.sh" -Wait
    Write-Host "Install p7zip .."
    Start-Process ".\IncludesLinux\bash\p7zip.sh" -Wait
    Write-Host "Install screen .."
    Start-Process ".\IncludesLinux\bash\screen.sh" -Wait
    Write-Host "Install virt-what .."
    Start-Process ".\IncludesLinux\bash\virt-what.sh" -Wait

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

    if ($IsLinux) {
        #if (Test-Path "/opt/amdgpu-pro/lib/x86_64-linux-gnu/libOpenCL.so.1.2") {
        #    if (-not (Test-Path "/opt/amdgpu-pro/lib/x86_64-linux-gnu/libOpenCL.so")) {
        #        Invoke-Exe -FilePath "ln" -ArgumentList "-nfs /opt/amdgpu-pro/lib/x86_64-linux-gnu/libOpenCL.so.1.2 /opt/amdgpu-pro/lib/x86_64-linux-gnu/libOpenCL.so" > $null
        #        Invoke-Exe -FilePath "ldconfig" > $null
        #        Write-Host " libOpenCL.so.1.2 found, but symbolic link needed to be created and ldconfig cache updated."
        #    } else {
        #        Write-Host " libOpenCL.so found."
        #    }
        #}
    }
}
if (-not $GNVIDIA -and -not $GAMD) {
    Write-Host " No GPUs found."
}

if ($IsLinux) {
    Get-ChildItem ".\Data" -Filter "*-names.json" -File -ErrorAction Ignore | Foreach-Object {& chmod a+rw "$($_.FullName)" > $null}
    Get-ChildItem ".\Data" -Filter "gpu-count.json" -File -ErrorAction Ignore | Foreach-Object {& chmod a+rw "$($_.FullName)" > $null}
}

if ($IsWindows -and $GNVIDIA) {
    try {
        $InstallNVSMI_Job = Start-Job -InitializationScript ([ScriptBlock]::Create("Set-Location `"$($PWD.Path -replace '"','``"')`"")) -FilePath .\Scripts\InstallNVSMI.ps1 -ArgumentList $NV_Version
        if ($InstallNVSMI_Job) {
            $InstallNVSMI_Job | Wait-Job -Timeout 60 > $null
            if ($InstallNVSMI_Job.State -eq 'Running') {
                Write-Host "WARNING: Time-out while loading .\Scripts\InstallNVSMI.ps1" -ForegroundColor Yellow
                try {$InstallNVSMI_Job | Stop-Job -PassThru | Receive-Job > $null} catch {if ($Error.Count){$Error.RemoveAt(0)}}
            } else {
                try {
                    $InstallNVSMI_Result = Receive-Job -Job $InstallNVSMI_Job
                    if ($InstallNVSMI_Result) {
                        $InstallNVSMI_Result | Foreach-Object {
                            if ($_ -match "^WARNING:\s*(.+)$") {
                                Write-Host $_ -ForegroundColor Yellow
                            } elseif ($_ -match "^SUCCESS:\s*(.+)$") {
                                Write-Host $_ -ForegroundColor Green
                            } else {
                                Write-Host $_
                            }
                        }
                    }
                } catch {if ($Error.Count){$Error.RemoveAt(0)}}
            }
            try {Remove-Job $InstallNVSMI_Job -Force} catch {if ($Error.Count){$Error.RemoveAt(0)}}
        }
    } catch {
        Write-Host "WARNING: Failed to check NVSMI: $($_.Exception.Message)"
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