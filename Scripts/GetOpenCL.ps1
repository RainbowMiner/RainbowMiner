
Add-Type -Path .\DotNet\OpenCL\*.cs

$Result = [PSCustomObject]@{
    Platform_Devices = $null
    ErrorMessage     = $null
}

[System.Collections.Generic.List[string]]$AllPlatforms = @()
try {
    $PlatformId = 0
    $Result.Platform_Devices = [OpenCl.Platform]::GetPlatformIDs() | Where-Object {$AllPlatforms -inotcontains "$($_.Name) $($_.Version)"} | ForEach-Object {
        $AllPlatforms.Add("$($_.Name) $($_.Version)") > $null
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
                    Type             = "$($_.Type)"
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
} catch {
    if ($Error.Count){$Error.RemoveAt(0)}
    $Result.ErrorMessage = $_.Exception.Message
}

$Result