
if ($IsLinux) {
    $exitcode = -1
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::New()
        $psi.FileName               = "ldconfig"
        $psi.CreateNoWindow         = $true
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.Arguments              = "-p"
        $process = [System.Diagnostics.Process]::New()
        $process.StartInfo = $psi
        [void]$process.Start()
        $out = $process.StandardOutput.ReadToEnd()
        $process.WaitForExit(5000)>$null
        $exitcode = $process.ExitCode
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
    } finally {
        if ($psi) {
            $process.Dispose()
        }
    }
    if ($exitcode -eq 0 -and $out -notmatch "libOpenCL.so[\s\t]") {
        $env:LD_LIBRARY_PATH = "$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})"
    }
}

Add-Type -Path .\DotNet\OpenCL\*.cs

$Result = [PSCustomObject]@{
    AllPlatforms = [System.Collections.Generic.List[string]]@()
    Platform_Devices = $null
    ErrorMessage = $null
    Status = $false
}

$PlatformId = 0

$Result.Platform_Devices = try {
    [OpenCl.Platform]::GetPlatformIDs() | Where-Object {$AllPlatforms -inotcontains "$($_.Name) $($_.Version)"} | ForEach-Object {
        $Result.AllPlatforms.Add("$($_.Name) $($_.Version)") > $null
        $Device_Index = 0
        $PlatformVendor = switch -Regex ([String]$_.Vendor) { 
                                "Advanced Micro Devices" {"AMD"}
                                "Intel"  {"INTEL"}
                                "NVIDIA" {"NVIDIA"}
                                "AMD"    {"AMD"}
                                default {$_.Vendor -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                    }
        [PSCustomObject]@{
            PlatformId=$PlatformId
            Vendor=$PlatformVendor
            Devices=[OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | Foreach-Object {
                [PSCustomObject]@{
                    DeviceIndex      = $Device_Index
                    Name             = $_.Name
                    Architecture     = $_.Architecture
                    Type             = $_.Type
                    Vendor           = $_.Vendor
                    GlobalMemSize    = $_.GlobalMemSize
                    GlobalMemSizeGB  = [int]($_.GlobalMemSize/1GB)
                    MaxComputeUnits  = $_.MaxComputeUnits
                    PlatformVersion  = $_.Platform.Version
                    DriverVersion    = $_.DriverVersion
                    PCIBusId         = $_.PCIBusId
                    DeviceCapability = $_.DeviceCapability
                    CardId           = -1
                }
                $Device_Index++
            }
        }
        $PlatformId++
    }
    $Result.Status = $true
} catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Result.ErrorMessage = $_.Exception.Message
}

$Result