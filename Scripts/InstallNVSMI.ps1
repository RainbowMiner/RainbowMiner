using module .\Modules\Include.psm1

param(
$NV_Version = ""
)

Initialize-Session

if (-not (Test-IsElevated)) {
    Write-Output "WARNING: Admin Privileges needed. Exiting without installation"
    exit
}

if (-not $NV_Version) {
    try {
        $data = @(Get-DeviceName "nvidia" -UseAfterburner $false | Select-Object)
        if (($data | Measure-Object).Count) {
            $NV_Version = "$($data[0].DriverVersion)"
        }
    } catch {
        $NV_Version = ""
    }
}

if (-not $NV_Version) {
    Write-Output "WARNING: NVIDIA configuration could not be read."
}

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
        Write-Output "WARNING: $($NV_Data.cur.path) is missing"
        $NV_Install += [PSCustomObject]@{from = $NV_File_Copy; to = $NV_Data.cur}
    } elseif ($NV_Version -and $NV_Data.cur.version) {
        if ($NV_Data.cur.version -ne $NV_Version) {
            Write-Output "WARNING: $($NV_Data.cur.path) has wrong version $($NV_Data.cur.version) vs. $NV_Version"
            if ($NV_File_Copy.version -ne $NV_Data.cur.version) {
                $NV_Install += [PSCustomObject]@{from = $NV_File_Copy; to = $NV_Data.cur}
            }
        }
    }
}
if ($NV_Install) {
    Write-Output "RainbowMiner will try to install NVSMI, but the driver version may be wrong!"
    try {
        if (-not (Test-Path $NV_Paths.cur)) {New-Item $NV_Paths.cur -ItemType "directory" > $null}

        foreach($NV_Fx in $NV_Install) {
            Copy-Item $NV_Fx.from.path -Destination $NV_Fx.to.path -Force
        }

        Write-Output "SUCCESS: NVSMI installed successfully!"
        $Install_NVSMI = $false
    } catch {
        Write-Output "WARNING: Failed to install NVSMI"
    }
}