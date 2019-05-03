using module .\Include.psm1

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

$TestFileName = "gputestresult.txt"

if ($IsWindows -eq $null) {
    if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
        $Global:IsWindows = $true
        $Global:IsLinux = $false
        $Global:IsMacOS = $false
    }
}

"GPU-TEST $((Get-Date).ToUniversalTime())" | Out-File $TestFileName -Encoding utf8
"="*80 | Out-File $TestFileName -Append
" " | Out-File $TestFileName -Append

if ($IsWindows) {
    Start-Afterburner

    "1. Afterburner NVIDIA" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    Get-AfterburnerDevices "NVIDIA" | Out-File $TestFileName -Encoding utf8 -Append

    " " | Out-File $TestFileName -Append
    "2. Afterburner AMD" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    Get-AfterburnerDevices "AMD" | Out-File $TestFileName -Encoding utf8 -Append

    " " | Out-File $TestFileName -Append
    "3. OverdriveN" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    Invoke-Exe '.\Includes\OverdriveN.exe' -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines | Out-File $TestFileName -Encoding utf8 -Append


    " " | Out-File $TestFileName -Append
    "4. nvidia-smi" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    $Arguments = @(
        '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
        '--format=csv,noheader'
    )

    Invoke-Exe ".\Includes\nvidia-smi.exe" -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines  | Out-File $TestFileName -Encoding utf8 -Append

    " " | Out-File $TestFileName -Append
    "5. OpenCL" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
        $_ | Out-File $TestFileName -Encoding utf8 -Append
        [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | Out-File $TestFileName -Encoding utf8 -Append
        "."*80 | Out-File $TestFileName -Append
    }

    "6. OverdriveNTool" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append
   
   $Arguments = @('-console-only','-getcurrent')
   Invoke-Exe ".\Includes\overdriventool.exe" -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines  | Out-File $TestFileName -Encoding utf8 -Append

}

if ($IsLinux) {
    " " | Out-File $TestFileName -Append
    "1. nvidia-smi" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    $Arguments = @(
        '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
        '--format=csv,noheader'
    )

    Invoke-Exe "nvidia-smi" -ArgumentList ($Arguments -join ' ') -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines  | Out-File $TestFileName -Encoding utf8 -Append

    " " | Out-File $TestFileName -Append
    "2. OpenCL" | Out-File $TestFileName -Append
    "-"*80 | Out-File $TestFileName -Append
    " " | Out-File $TestFileName -Append

    [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
        $_ | Out-File $TestFileName -Encoding utf8 -Append
        [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | Out-File $TestFileName -Encoding utf8 -Append
        "."*80 | Out-File $TestFileName -Append
    }
}

Write-Host "Done! Now please drop the file"
Write-Host " "
Write-Host $(Resolve-Path $TestFileName | Select-Object -ExpandProperty Path) -ForegroundColor Yellow
Write-Host " "
Write-Host "onto your issue at https://github.com/RainbowMiner/RainbowMiner/issues"
Write-Host " "
