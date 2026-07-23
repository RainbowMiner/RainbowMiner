
Add-Type -Path .\DotNet\OpenCL\*.cs

$Result = [PSCustomObject]@{
    Platform_Devices = $null
    ErrorMessage     = $null
}

[System.Collections.Generic.List[string]]$AllPlatforms = @()
[System.Collections.Generic.List[string]]$PlatformErrors = @()
try {
    $PlatformId = 0
    $Result.Platform_Devices = [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {

        $Platform_OpenCL = $_

        try {

            $PlatformVendor = switch -Regex ([String]$Platform_OpenCL.Vendor) {
                                    "Advanced Micro Devices" {"AMD"}
                                    "Intel"  {"INTEL"}
                                    "NVIDIA" {"NVIDIA"}
                                    "AMD"    {"AMD"}
                                    default {$Platform_OpenCL.Vendor -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                        }

            if (($Global:IsLinux -and $PlatformVendor -eq "AMD") -or $AllPlatforms -inotcontains "$($Platform_OpenCL.Name) $($Platform_OpenCL.Version)") {

                $Platform_Devices = @([OpenCl.Device]::GetDeviceIDs($Platform_OpenCL, [OpenCl.DeviceType]::All))

                if ($Platform_Devices.Count) {

                    [void]$AllPlatforms.Add("$($Platform_OpenCL.Name) $($Platform_OpenCL.Version)")
                    $Device_Index = 0
                    [PSCustomObject]@{
                        PlatformId=$PlatformId
                        Vendor=$PlatformVendor
                        Name="$($Platform_OpenCL.Name) $($Platform_OpenCL.Version)"
                        Devices=$Platform_Devices | Foreach-Object {
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
            }
        } catch {
            [void]$PlatformErrors.Add($_.Exception.Message)
        }
    }
} catch {
    $Result.ErrorMessage = $_.Exception.Message
}

if (-not $Result.ErrorMessage -and $PlatformErrors.Count -and -not ($Result.Platform_Devices | Where-Object {$_.Devices})) {
    $Result.ErrorMessage = $PlatformErrors -join "; "
}

$Result
