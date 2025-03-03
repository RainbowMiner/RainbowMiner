#
# Device detection
#

function Get-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @(),
        [Parameter(Mandatory = $false)]
        [String[]]$ExcludeName = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$Refresh = $false,
        [Parameter(Mandatory = $false)]
        [Switch]$IgnoreOpenCL = $false
    )

    if ($Name) {
        $DeviceList = Get-ContentByStreamReader ".\Data\devices.json" | ConvertFrom-Json -ErrorAction Ignore
        $Name_Devices = $Name | ForEach-Object {
            $Name_Split = @("*","*","*")
            $ix = 0;foreach ($a in ($_ -split '#' | Select-Object -First 3)) {$Name_Split[$ix] = if ($ix -gt 0) {[int]$a} else {$a};$ix++}
            if ($DeviceList.("{0}" -f $Name_Split)) {
                $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
                $Name_Device.PSObject.Properties.Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}
                $Name_Device
            }
        }
    }

    if ($ExcludeName) {
        if (-not $DeviceList) {$DeviceList = Get-ContentByStreamReader ".\Data\devices.json" | ConvertFrom-Json -ErrorAction Ignore}
        $ExcludeName_Devices = $ExcludeName | ForEach-Object {
            $Name_Split = @("*","*","*")
            $ix = 0;foreach ($a in ($_ -split '#' | Select-Object -First 3)) {$Name_Split[$ix] = if ($ix -gt 0) {[int]$a} else {$a};$ix++}
            if ($DeviceList.("{0}" -f $Name_Split)) {
                $Name_Device = $DeviceList.("{0}" -f $Name_Split) | Select-Object *
                $Name_Device.PSObject.Properties.Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}
                $Name_Device
            }
        }
    }

    if (-not (Test-Path Variable:Global:GlobalCachedDevices) -or $Refresh) {
        $Global:GlobalCachedDevices = [System.Collections.ArrayList]@()

        $PlatformId = 0
        $Index = 0
        $PlatformId_Index = @{}
        $Type_PlatformId_Index = @{}
        $Vendor_Index = @{}
        $Type_Vendor_Index = @{}
        $Type_Index = @{}
        $Type_Mineable_Index = @{}
        $Type_Codec_Index = @{}
        $GPUVendorLists = @{}
        $GPUDeviceNames = @{}

        $KnownVendors = @("AMD","INTEL","NVIDIA")

        $DriverVersion_LHR_Removed = Get-Version "522.25"

        foreach ($GPUVendor in $KnownVendors) {$GPUVendorLists | Add-Member $GPUVendor @(Get-GPUVendorList $GPUVendor)}

        $OldLD = $null
        
        if ($IsWindows) {
            #Get WDDM data               
            $Global:WDDM_Devices = try {
                Get-CimInstance CIM_VideoController | ForEach-Object {
                    $BusId = $null
                    try {
                        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)"
                        if (Test-Path $RegPath) {
                            $RegProperties = Get-ItemProperty -Path $RegPath
            
                            if ($RegProperties.PSObject.Properties.Match('locationInformation')) {
                                if ($RegProperties.locationInformation -match "\d+,\d+,\d+") {
                                    $BusId = "$("{0:x2}:{1:x2}" -f ($Matches[0] -split "," | ForEach-Object {[int]$_}))"
                                }
                            }
                        }
                    } catch {
                        $BusId = $null
                    }

                    if (-not $BusId -or $BusId -notmatch "[0-9A-F]+:[0-9A-F]+") {
                        $PnpInfo = Get-PnpDevice $_.PNPDeviceId | Get-PnpDeviceProperty "DEVPKEY_Device_BusNumber","DEVPKEY_Device_Address" -ErrorAction Ignore
                        $BusNumber     = ($PnpInfo | Where-Object KeyName -eq "DEVPKEY_Device_BusNumber").Data
                        $DeviceAddress = ($PnpInfo | Where-Object KeyName -eq "DEVPKEY_Device_Address").Data
                        $BusId = if ($BusNumber -ne $null -and $BusNumber.GetType() -match "int") {"{0:x2}:{1:x2}" -f $BusNumber,([int]$DeviceAddress -shr 16)} else {$null}
                    }
                    
                    if ($DeviceAddress -eq $null) {$DeviceAddress = 0}
                    [PSCustomObject]@{
                        Name        = $_.Name
                        InstanceId  = $_.PNPDeviceId
                        BusId       = $BusId
                        SubId       = if ($_.PNPDeviceId -match "DEV_([0-9A-F]{4})") {$Matches[1]} else {$null}
                        Vendor      = switch -Regex ([String]$_.AdapterCompatibility) { 
                                        "Advanced Micro Devices" {"AMD"}
                                        "Intel"  {"INTEL"}
                                        "NVIDIA" {"NVIDIA"}
                                        "AMD"    {"AMD"}
                                        default {$_.AdapterCompatibility -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                            }
                    }
                }
            }
            catch {
                Write-Log -Level Warn "WDDM device detection has failed. "
            }
            $Global:WDDM_Devices = @($Global:WDDM_Devices | Sort-Object {[int]"0x0$($_.BusId -replace "[^0-9A-F]+")"})
        } else {

            $ldconfig = Invoke-Exe "ldconfig" -ArgumentList "-p"

            if ($Global:LASTEXEEXITCODE -eq 0 -and $ldconfig -notmatch "libOpenCL.so[\s\t]") {
                $oldLD = "$($env:LD_LIBRARY_PATH)"
                $env:LD_LIBRARY_PATH = "$(if ($env:LD_LIBRARY_PATH) {"$($env:LD_LIBRARY_PATH):"})$(if (Test-Path "/opt/rainbowminer/lib") {"/opt/rainbowminer/lib"} else {(Resolve-Path ".\IncludesLinux\lib")})"
            }
        }

        $Platform_Devices = $null
        $ErrorMessage     = $null

        try {
            $GetOpenCL_Job = Start-Job -InitializationScript ([ScriptBlock]::Create("Set-Location `"$($PWD.Path -replace '"','``"')`"")) -FilePath .\Scripts\GetOpenCL.ps1
            if ($GetOpenCL_Job) {
                $GetOpenCL_Job | Wait-Job -Timeout 60 > $null
                if ($GetOpenCL_Job.State -eq 'Running') {
                    try {$GetOpenCL_Job | Stop-Job -PassThru | Receive-Job > $null} catch {}
                    $ErrorMessage = "Timeout"
                } else {
                    try {
                        $GetOpenCL_Result = Receive-Job -Job $GetOpenCL_Job
                        $Platform_Devices = $GetOpenCL_Result.Platform_Devices
                        $ErrorMessage     = $GetOpenCL_Result.ErrorMessage
                    } catch {}
                }
                try {Remove-Job $GetOpenCL_Job -Force} catch {}
            }
        } catch {
            $ErrorMessage = "$($_.Exception.Message)"
        } finally {
            if ($oldLD -ne $null) {$env:LD_LIBRARY_PATH = $oldLD}
        }

        if ($ErrorMessage) {
            Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "OpenCL detection failed: $($ErrorMessage)"
            $Cuda = Get-NvidiaSmi | Where-Object {$_} | Foreach-Object {Invoke-Exe $_ -ExcludeEmptyLines -ExpandLines | Where-Object {$_ -match "CUDA.+?:\s*(\d+\.\d+)"} | Foreach-Object {$Matches[1]} | Select-Object -First 1 | Foreach-Object {"$_.0"}}
            if ($Cuda) {
                $OpenCL_Devices = Invoke-NvidiaSmi "index","gpu_name","memory.total","pci.bus_id","pci.device_id" | Where-Object {$_.index -match "^\d+$"} | Sort-Object index | Foreach-Object {
                    [PSCustomObject]@{
                        DeviceIndex     = $_.index
                        Name            = $_.gpu_name
                        Architecture    = $_.gpu_name
                        Type            = "Gpu"
                        Vendor          = "NVIDIA Corporation"
                        GlobalMemSize   = 1MB * [int64]$_.memory_total
                        GlobalMemSizeGB = [int]($_.memory_total/1kB)
                        PlatformVersion = "CUDA $Cuda"
                        PCIBusId        = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                        SubId           = if ($_.pci_device_id -match "^0x([0-9A-F]{4})") {$Matches[1]} else {$null}
                        CardId          = -1
                    }
                }
                if ($OpenCL_Devices) {
                    Write-Log "CUDA found: successfully configured devices via nvidia-smi"
                    $Platform_Devices = [PSCustomObject]@{PlatformId=0;Vendor="NVIDIA";Devices=$OpenCL_Devices}
                } else {
                    Write-Log "CUDA found: failed to configure devices via nvidia-smi"
                }
            }
        }

        try {
            $AmdModels   = @{}
            [System.Collections.Generic.List[string]]$AmdModelsEx = @()
            [System.Collections.Generic.List[string]]$PCIBusIds = @()
            $Platform_Devices | Foreach-Object {
                $PlatformId = $_.PlatformId
                $PlatformVendor = $_.Vendor
                $_.Devices | Where-Object {$_} | Foreach-Object {    
                    $Device_OpenCL = $_

                    $Vendor_Name = [String]$Device_OpenCL.Vendor

                    if ($GPUVendorLists.NVIDIA -icontains $Vendor_Name) {
                        $Vendor_Name = "NVIDIA"
                    } elseif ($GPUVendorLists.AMD -icontains $Vendor_Name) {
                        $Vendor_Name = "AMD"
                    } elseif ($GPUVendorLists.INTEL -icontains $Vendor_Name) {
                        $Vendor_Name = "INTEL"
                    }

                    $Device_Name = Get-NormalizedDeviceName $Device_OpenCL.Name -Vendor $Vendor_Name
                    $InstanceId  = ''
                    $SubId = "$($Device_OpenCL.SubId)"
                    $PCIBusId = $null
                    $CardId = -1

                    if (-not $GPUDeviceNames[$Vendor_Name]) {
                        $UseAB = $false
                        if ($Vendor_Name -eq "AMD") {
                            $GPUDeviceNames[$Vendor_Name] = if ($IsLinux) {
                                if ((Test-OCDaemon) -or (Test-IsElevated)) {
                                    try {
                                        $data = @(Get-DeviceName "amd" -UseAfterburner $false | Select-Object)
                                        if (($data | Measure-Object).Count) {Set-ContentJson ".\Data\amd-names.json" -Data $data > $null}
                                    } catch {}
                                }
                                if (Test-Path ".\Data\amd-names.json") {Get-ContentByStreamReader ".\Data\amd-names.json" | ConvertFrom-Json -ErrorAction Ignore}
                            }
                            $UseAB = $OpenCL_DeviceIDs.Count -lt 7
                        }
                        if (-not $GPUDeviceNames[$Vendor_Name]) {
                            $GPUDeviceNames[$Vendor_Name] = Get-DeviceName $Vendor_Name -UseAfterburner $UseAB
                        }
                    }

                    $GPUDeviceNameFound = $null
                    if ($Device_OpenCL.PCIBusId -match "[A-F0-9]+:[A-F0-9]+$") {
                        $GPUDeviceNameFound = $GPUDeviceNames[$Vendor_Name] | Where-Object PCIBusId -eq $Device_OpenCL.PCIBusId | Select-Object -First 1
                    }
                    if (-not $GPUDeviceNameFound) {
                        $GPUDeviceNameFound = $GPUDeviceNames[$Vendor_Name] | Where-Object Index -eq ([Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)") | Select-Object -First 1
                    }

                    if ($Vendor_Name -eq "AMD") {
                        if ($GPUDeviceNameFound) {
                            $Device_Name = $GPUDeviceNameFound.DeviceName
                            $InstanceId  = $GPUDeviceNameFound.InstanceId
                            $SubId       = $GPUDeviceNameFound.SubId
                            $PCIBusId    = $GPUDeviceNameFound.PCIBusId
                            $CardId      = $GPUDeviceNameFound.CardId
                        }

                        # fix some AMD names
                        if ($SubId -eq "687F" -or $Device_Name -eq "Radeon RX Vega" -or $Device_Name -eq "gfx900") {
                            if ($Device_OpenCL.MaxComputeUnits -eq 56) {$Device_Name = "Radeon Vega 56"}
                            elseif ($Device_OpenCL.MaxComputeUnits -eq 64) {$Device_Name = "Radeon Vega 64"}
                        } elseif ($Device_Name -eq "gfx906" -or $Device_Name -eq "gfx907") {
                            $Device_Name = "Radeon VII"
                        } elseif ($Device_Name -eq "gfx1010") {
                            $Device_Name = "Radeon RX 5700 XT"
                        }

                        # fix PCIBusId
                        if ($PCIBusId) {$Device_OpenCL.PCIBusId = $PCIBusId}

                        # fix Architecture
                        if ($Device_OpenCL.Architecture -match "^(gfx\d+)") {
                            $Device_OpenCL.Architecture = $Matches[1]
                        } else {
                            $Device_OpenCL.Architecture = "$($Device_OpenCL.Architecture -replace ":.+$" -replace "[^A-Za-z0-9]+")"
                        }
                    } elseif ($Vendor_Name -eq "INTEL") {
                        # nothing to fix yet
                    } elseif ($Vendor_Name -eq "NVIDIA") {
                        if ($GPUDeviceNameFound) {
                            $SubId       = $GPUDeviceNameFound.SubId
                        }
                    }

                    $Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")

                    if ($Model -eq "") { #alas! empty
                        if ($Device_OpenCL.Architecture) {
                            $Model = $Device_OpenCL.Architecture
                            $Device_Name = "$($Device_Name)$(if ($Device_Name) {" "})$($Model)"
                        } elseif ($InstanceId -and $InstanceId -match "VEN_([0-9A-F]{4}).+DEV_([0-9A-F]{4}).+SUBSYS_([0-9A-F]{4,8})") {
                            try {
                                $Result = Invoke-GetUrl "https://api.rbminer.net/pciids.php?ven=$($Matches[1])&dev=$($Matches[2])&subsys=$($Matches[3])"
                                if ($Result.status) {
                                    $Device_Name = if ($Result.data -match "\[(.+)\]") {$Matches[1]} else {$Result.data}
                                    if ($Vendor_Name -eq "AMD" -and $Device_Name -notmatch "Radeon") {$Device_Name = "Radeon $($Device_Name)"}
                                    $Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")
                                }
                            } catch {
                            }
                        }
                        if ($Model -eq "") {
                            $Model = "Unknown"
                            $Device_Name = "$($Device_Name)$(if ($Device_Name) {" "})$($Model)"
                        }
                    }

                    if ($Vendor_Name -eq "NVIDIA") {
                        $Codec = "CUDA"
                        $Device_OpenCL.Architecture = Get-NvidiaArchitecture $Model $Device_OpenCL.DeviceCapability
                    } else {
                        $Codec = "OpenCL"
                        if ($Vendor_Name -eq "AMD") {
                            $Device_OpenCL.DeviceCapability = Get-AMDComputeCapability $Model $Device_OpenCL.Architecture
                        }
                    }

                    $Device = [PSCustomObject]@{
                        Name = ""
                        Index = [Int]$Index
                        PlatformId = [Int]$PlatformId
                        PlatformId_Index = [Int]$PlatformId_Index."$($PlatformId)"
                        Type_PlatformId_Index = [Int]$Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"
                        Platform_Vendor = $PlatformVendor
                        Vendor = [String]$Vendor_Name
                        Vendor_Name = [String]$Device_OpenCL.Vendor
                        Vendor_Index = [Int]$Vendor_Index."$($Device_OpenCL.Vendor)"
                        Type = [String]$Device_OpenCL.Type
                        Type_Index = [Int]$Type_Index."$($Device_OpenCL.Type)"
                        Type_Codec_Index = [Int]$Type_Codec_Index."$($Device_OpenCL.Type)".$Codec
                        Type_Mineable_Index = [Int]$Type_Mineable_Index."$($Device_OpenCL.Type)"
                        Type_Vendor_Index = [Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"
                        BusId_Index               = 0
                        BusId_Type_Index          = 0
                        BusId_Type_Codec_Index    = 0
                        BusId_Type_Vendor_Index   = 0
                        BusId_Type_Mineable_Index = 0
                        BusId_Vendor_Index        = 0

                        OpenCL = $Device_OpenCL
                        Codec = $Codec
                        Model = $Model
                        Model_Base = $Model
                        Model_Name = [String]$Device_Name
                        InstanceId = [String]$InstanceId
                        CardId = $CardId
                        BusId = $null
                        SubId = $SubId
                        IsLHR = $false
                        GpuGroup = ""

                        Data = [PSCustomObject]@{
                                        AdapterId         = 0  #amd
                                        Utilization       = 0  #amd/nvidia
                                        UtilizationMem    = 0  #amd/nvidia
                                        Clock             = 0  #amd/nvidia
                                        ClockMem          = 0  #amd/nvidia
                                        FanSpeed          = 0  #amd/nvidia
                                        Temperature       = 0  #amd/nvidia
                                        PowerDraw         = 0  #amd/nvidia
                                        PowerLimit        = 0  #nvidia
                                        PowerLimitPercent = 0  #amd/nvidia
                                        PowerMaxLimit     = 0  #nvidia
                                        PowerDefaultLimit = 0  #nvidia
                                        Pstate            = "" #nvidia
                                        Method            = "" #amd/nvidia
                        }
                        DataMax = [PSCustomObject]@{
                                    Clock       = 0
                                    ClockMem    = 0
                                    Temperature = 0
                                    FanSpeed    = 0
                                    PowerDraw   = 0
                        }
                    }

                    if ($Device.Type -ne "Cpu") {
                        $Device.Name = ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper()
                        if ($AmdModelsEx -notcontains $Device.Model) {
                            $AmdGb = $Device.OpenCL.GlobalMemSizeGB
                            if ($AmdModels.ContainsKey($Device.Model) -and $AmdModels[$Device.Model] -ne $AmdGb) {[void]$AmdModelsEx.Add($Device.Model)}
                            else {$AmdModels[$Device.Model]=$AmdGb}
                        }
                        if ($Vendor_Name -in @("NVIDIA","AMD")) {$Type_Mineable_Index."$($Device_OpenCL.Type)"++}
                        if ($Device_OpenCL.PCIBusId -match "([A-F0-9]+:[A-F0-9]+)$") {
                            $Device.BusId = $Matches[1]
                            if ($PCIBusIds.Contains($Device.BusId)) {$Device = $null} else {[void]$PCIBusIds.Add($Device.BusId)}
                        }

                        if ($Device) {
                            if ($IsWindows) {
                                $Global:WDDM_Devices | Where-Object {$_.Vendor -eq $Vendor_Name} | Select-Object -Index $Device.Type_Vendor_Index | Foreach-Object {
                                    if ($_.BusId -ne $null -and $Device.BusId -eq $null) {$Device.BusId = $_.BusId}
                                    if ($_.InstanceId -and $Device.InstanceId -eq "")    {$Device.InstanceId = $_.InstanceId}
                                    if ($_.SubId -and $Device.SubId -eq "")              {$Device.SubId = $_.SubId}
                                }
                            }

                            if ($Vendor_Name -eq "NVIDIA" -and (-not $Device.OpenCL.DriverVersion -or (Get-Version $Device.OpenCL.DriverVersion) -lt $DriverVersion_LHR_Removed)) {
                                $Device.IsLHR = $Model -match "^RTX30[1-8]0" -and $Device.SubId -notin @("2204","2206","2484","2486")
                            }

                            [void]$Global:GlobalCachedDevices.Add($Device)
                            $Index++
                        }
                    }

                    if ($Device) {
                        if (-not $Type_Codec_Index."$($Device_OpenCL.Type)") {
                            $Type_Codec_Index."$($Device_OpenCL.Type)" = @{}
                        }
                        if (-not $Type_PlatformId_Index."$($Device_OpenCL.Type)") {
                            $Type_PlatformId_Index."$($Device_OpenCL.Type)" = @{}
                        }
                        if (-not $Type_Vendor_Index."$($Device_OpenCL.Type)") {
                            $Type_Vendor_Index."$($Device_OpenCL.Type)" = @{}
                        }

                        $PlatformId_Index."$($PlatformId)"++
                        $Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"++
                        $Vendor_Index."$($Device_OpenCL.Vendor)"++
                        $Type_Index."$($Device_OpenCL.Type)"++
                        $Type_Codec_Index."$($Device_OpenCL.Type)".$Codec++
                        $Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"++
                    }
                }
            }

            $AmdModelsEx | Foreach-Object {
                $Model = $_
                $Global:GlobalCachedDevices | Where-Object Model -eq $Model | Foreach-Object {
                    $AmdGb = "$($_.OpenCL.GlobalMemSizeGB)GB"
                    $_.Model = "$($_.Model)$AmdGb"
                    $_.Model_Base = "$($_.Model_Base)$AmdGb"
                    $_.Model_Name = "$($_.Model_Name) $AmdGb"
                }
            }
        }
        catch {
            Write-Log -Level $(if ($IgnoreOpenCL) {"Info"} else {"Warn"}) "GPU detection has failed: $($_.Exception.Message)"
        }

        #re-index in case the OpenCL platforms have shifted positions
        if ($Platform_Devices) {
            try {
                if ($Session.OpenCLPlatformSorting) {
                    $OpenCL_Platforms = $Session.OpenCLPlatformSorting
                } elseif (Test-Path ".\Data\openclplatforms.json") {
                    $OpenCL_Platforms = Get-ContentByStreamReader ".\Data\openclplatforms.json" | ConvertFrom-Json -ErrorAction Ignore
                }

                if (-not $OpenCL_Platforms) {
                    $OpenCL_Platforms = @()
                }

                $OpenCL_Platforms_Current = @($Platform_Devices | Sort-Object {$_.Vendor -notin $KnownVendors},PlatformId | Foreach-Object {"$($_.Vendor)"})

                if (Compare-Object $OpenCL_Platforms $OpenCL_Platforms_Current | Where-Object SideIndicator -eq "=>") {
                    $OpenCL_Platforms_Current | Where-Object {$_ -notin $OpenCL_Platforms} | Foreach-Object {$OpenCL_Platforms += $_}
                    if (-not $Session.OpenCLPlatformSorting -or -not (Test-Path ".\Data\openclplatforms.json")) {
                        Set-ContentJson -PathToFile ".\Data\openclplatforms.json" -Data $OpenCL_Platforms > $null
                    }
                }

                $Index = 0
                $Need_Sort = $false

                # Sort the original list in place using Sort()
                $Global:GlobalCachedDevices.Sort([System.Collections.Generic.Comparer[object]]::Create({
                    param ($a, $b)
                    $PlatformComparison = $OpenCL_Platforms.IndexOf($a.Platform_Vendor) - $OpenCL_Platforms.IndexOf($b.Platform_Vendor)
                    if ($PlatformComparison -ne 0) {
                        return $PlatformComparison
                    }
                    return $a.Index - $b.Index
                }))

                # Adjust indices without creating a new list
                foreach ($Device in $Global:GlobalCachedDevices) {
                    if ($Device.Index -ne $Index) {
                        $Need_Sort = $true
                        $Device.Index = $Index
                        $Device.Name = ("{0}#{1:d2}" -f $Device.Type, $Index).ToUpper()
                    }
                    $Index++
                }

                if ($Need_Sort) {
                    Write-Log "OpenCL platforms have changed from initial run. Resorting indices."
                }

            } catch {
                Write-Log -Level Warn "OpenCL platform detection failed: $($_.Exception.Message)"
            }
        }

        #Roundup and add sort order by PCI busid
        $BusId_Index = 0
        $BusId_Type_Index = @{}
        $BusId_Type_Codec_Index = @{}
        $BusId_Type_Vendor_Index = @{}
        $BusId_Type_Mineable_Index = @{}
        $BusId_Vendor_Index = @{}

        $Global:GlobalCachedDevices | Sort-Object {[int]"0x0$($_.BusId -replace "[^0-9A-F]+")"},Index | Foreach-Object {
            $_.BusId_Index               = $BusId_Index++
            $_.BusId_Type_Index          = [int]$BusId_Type_Index."$($_.Type)"
            $_.BusId_Type_Codec_Index    = [int]$BusId_Type_Codec_Index."$($_.Type)"."$($_.Codec)"
            $_.BusId_Type_Vendor_Index   = [int]$BusId_Type_Vendor_Index."$($_.Type)"."$($_.Vendor)"
            $_.BusId_Type_Mineable_Index = [int]$BusId_Type_Mineable_Index."$($_.Type)"
            $_.BusId_Vendor_Index        = [int]$BusId_Vendor_Index."$($_.Vendor)"

            if (-not $BusId_Type_Codec_Index."$($_.Type)") { 
                $BusId_Type_Codec_Index."$($_.Type)" = @{}
            }

            if (-not $BusId_Type_Vendor_Index."$($_.Type)") { 
                $BusId_Type_Vendor_Index."$($_.Type)" = @{}
            }

            $BusId_Type_Index."$($_.Type)"++
            $BusId_Type_Codec_Index."$($_.Type)"."$($_.Codec)"++
            $BusId_Type_Vendor_Index."$($_.Type)"."$($_.Vendor)"++
            $BusId_Vendor_Index."$($_.Vendor)"++
            if ($_.Vendor -in @("AMD","NVIDIA")) {$BusId_Type_Mineable_Index."$($_.Type)"++}
        }

        #CPU detection
        try {
            if ($Refresh -or -not (Test-Path Variable:Global:GlobalCPUInfo)) {

                $Global:GlobalCPUInfo = [PSCustomObject]@{}

                if ($IsWindows) {
                    try {
                        $CIM_CPU = Get-CimInstance -ClassName CIM_Processor
                        $Global:GlobalCPUInfo | Add-Member Name          "$($CIM_CPU[0].Name)".Trim()
                        $Global:GlobalCPUInfo | Add-Member Manufacturer  "$($CIM_CPU[0].Manufacturer)".Trim()
                        $Global:GlobalCPUInfo | Add-Member Cores         ($CIM_CPU.NumberOfCores | Measure-Object -Sum).Sum
                        $Global:GlobalCPUInfo | Add-Member Threads       ($CIM_CPU.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
                        $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($CIM_CPU | Measure-Object).Count
                        $Global:GlobalCPUInfo | Add-Member L3CacheSize   $CIM_CPU[0].L3CacheSize
                        $Global:GlobalCPUInfo | Add-Member MaxClockSpeed $CIM_CPU[0].MaxClockSpeed
                        $Global:GlobalCPUInfo | Add-Member TDP           0
                        $Global:GlobalCPUInfo | Add-Member Family        0
                        $Global:GlobalCPUInfo | Add-Member Model         0
                        $Global:GlobalCPUInfo | Add-Member Stepping      0
                        $Global:GlobalCPUInfo | Add-Member Architecture  ""
                        $Global:GlobalCPUInfo | Add-Member Features      @{}

                        try {
                            $lscpu = Get-CpuInfo
                            $Global:GlobalCPUInfo.Family   = $lscpu.family
                            $Global:GlobalCPUInfo.Model    = $lscpu.model
                            $Global:GlobalCPUInfo.Stepping = $lscpu.stepping
                            $lscpu.features | Foreach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
                        } catch {
                        }


                        if (-not $Global:GlobalCPUInfo.Features.Count) {
                            try {
                                $lscpu = Invoke-Exe ".\Includes\list_cpu_features.exe" -ArgumentList "--json" -WorkingDirectory $Pwd | ConvertFrom-Json -ErrorAction Stop
                                $Global:GlobalCPUInfo.Family   = $lscpu.family
                                $Global:GlobalCPUInfo.Model    = $lscpu.model
                                $Global:GlobalCPUInfo.Stepping = $lscpu.stepping
                                $lscpu.flags | Foreach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
                            } catch {
                            }

                            if (-not $Global:GlobalCPUInfo.Features.Count) {
                                $chkcpu = @{}
                                try {([xml](Invoke-Exe ".\Includes\CHKCPU32.exe" -ArgumentList "/x" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines)).chkcpu32.ChildNodes | Foreach-Object {$chkcpu[$_.Name] = if ($_.'#text' -match "^(\d+)") {[int]$Matches[1]} else {$_.'#text'}}} catch {}
                                $chkcpu.Keys | Where-Object {"$($chkcpu.$_)" -eq "1" -and $_ -notmatch '_' -and $_ -notmatch "^l\d$"} | Foreach-Object {$Global:GlobalCPUInfo.Features.$_ = $true}
                            }
                        }

                        if (-not $Global:GlobalCPUInfo.Family   -and $CIM_CPU[0].Caption -match "Family\s*(\d+)")   {$Global:GlobalCPUInfo.Family   = $Matches[1]}
                        if (-not $Global:GlobalCPUInfo.Model    -and $CIM_CPU[0].Caption -match "Model\s*(\d+)")    {$Global:GlobalCPUInfo.Model    = $Matches[1]}
                        if (-not $Global:GlobalCPUInfo.Stepping -and $CIM_CPU[0].Caption -match "Stepping\s*(\d+)") {$Global:GlobalCPUInfo.Stepping = $Matches[1]}
                    } catch {
                    }

                    if (-not $Global:GlobalCPUInfo.Features -or -not $Global:GlobalCPUInfo.Features.Count) {
                        Write-Log -Level Info "CIM CPU detection has failed. Trying alternative."

                        # Windows has problems to identify the CPU, so use fallback
                        $chkcpu = @{}
                        try {([xml](Invoke-Exe ".\Includes\CHKCPU32.exe" -ArgumentList "/x" -WorkingDirectory $Pwd -ExpandLines -ExcludeEmptyLines)).chkcpu32.ChildNodes | Foreach-Object {$chkcpu[$_.Name] = if ($_.'#text' -match "^(\d+)") {[int]$Matches[1]} else {$_.'#text'}}} catch {}

                        $Global:GlobalCPUInfo = [PSCustomObject]@{}

                        $Global:GlobalCPUInfo | Add-Member Name          "$($chkcpu.cpu_name)".Trim()
                        $Global:GlobalCPUInfo | Add-Member Manufacturer  "$($chkcpu.cpu_vendor)".Trim()
                        $Global:GlobalCPUInfo | Add-Member Cores         ([int]$chkcpu.cores)
                        $Global:GlobalCPUInfo | Add-Member Threads       ([int]$chkcpu.threads)
                        $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ([int]$chkcpu.physical_cpus)
                        $Global:GlobalCPUInfo | Add-Member L3CacheSize   ([int]$chkcpu.l3)
                        $Global:GlobalCPUInfo | Add-Member MaxClockSpeed ([int]$chkcpu.cpu_speed)
                        $Global:GlobalCPUInfo | Add-Member TDP           0
                        $Global:GlobalCPUInfo | Add-Member Family        0
                        $Global:GlobalCPUInfo | Add-Member Model         0
                        $Global:GlobalCPUInfo | Add-Member Stepping      0
                        $Global:GlobalCPUInfo | Add-Member Architecture  ""
                        $Global:GlobalCPUInfo | Add-Member Features      @{}

                        $chkcpu.Keys | Where-Object {"$($chkcpu.$_)" -eq "1" -and $_ -notmatch '_' -and $_ -notmatch "^l\d$"} | Foreach-Object {$Global:GlobalCPUInfo.Features.$_ = $true}

                        try {
                            $lscpu = Get-CpuInfo
                            $Global:GlobalCPUInfo.Family   = $lscpu.family
                            $Global:GlobalCPUInfo.Model    = $lscpu.model
                            $Global:GlobalCPUInfo.Stepping = $lscpu.stepping
                            $lscpu.features | Foreach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]")" = $true}
                        } catch {
                        }

                    }

                    $Global:GlobalCPUInfo.Features."$(if ([Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"})" = $true

                } elseif ($IsLinux) {
                    try {
                        Write-ToFile -FilePath ".\Data\lscpu.txt" -Message "$(Invoke-Exe "lscpu")" -NoCR > $null
                    } catch {
                    }

                    $Data = Get-Content "/proc/cpuinfo"
                    if ($Data) {
                        $Global:GlobalCPUInfo | Add-Member Name          "$((($Data | Where-Object {$_ -match 'model name'} | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Manufacturer  "$((($Data | Where-Object {$_ -match 'vendor_id'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Cores         ([int]"$((($Data | Where-Object {$_ -match 'cpu cores'}  | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member Threads       ([int]"$((($Data | Where-Object {$_ -match 'siblings'}   | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member PhysicalCPUs  ($Data | Where-Object {$_ -match 'physical id'} | Select-Object -Unique | Measure-Object).Count
                        $Global:GlobalCPUInfo | Add-Member L3CacheSize   ([int](ConvertFrom-Bytes "$((($Data | Where-Object {$_ -match 'cache size'} | Select-Object -First 1) -split ":")[1])".Trim())/1024)
                        $Global:GlobalCPUInfo | Add-Member MaxClockSpeed ([int]"$((($Data | Where-Object {$_ -match 'cpu MHz'}    | Select-Object -First 1) -split ":")[1])".Trim())
                        $Global:GlobalCPUInfo | Add-Member TDP           0
                        $Global:GlobalCPUInfo | Add-Member Family        "$((($Data | Where-Object {$_ -match 'cpu family'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Model         "$((($Data | Where-Object {$_ -match 'model\s*:'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Stepping      "$((($Data | Where-Object {$_ -match 'stepping'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Architecture  "$((($Data | Where-Object {$_ -match 'CPU architecture'}  | Select-Object -First 1) -split ":")[1])".Trim()
                        $Global:GlobalCPUInfo | Add-Member Features      @{}

                        $Processors = ($Data | Where-Object {$fld = $_ -split ":";$fld.Count -gt 1 -and $fld[0].Trim() -eq "processor" -and $fld[1].Trim() -match "^[0-9]+$"} | Measure-Object).Count

                        if (-not $Global:GlobalCPUInfo.PhysicalCPUs) {$Global:GlobalCPUInfo.PhysicalCPUs = 1}
                        if (-not $Global:GlobalCPUInfo.Cores)   {$Global:GlobalCPUInfo.Cores = 1}
                        if (-not $Global:GlobalCPUInfo.Threads) {$Global:GlobalCPUInfo.Threads = 1}

                        @("Family","Model","Stepping","Architecture") | Foreach-Object {
                            if ($Global:GlobalCPUInfo.$_ -match "^[0-9a-fx]+$") {$Global:GlobalCPUInfo.$_ = [int]$Global:GlobalCPUInfo.$_}
                        }

                        "$((($Data | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$ft = "$($_ -replace "[^a-z0-9]+")";if ($ft -ne "") {$Global:GlobalCPUInfo.Features.$ft = $true}}
                        "$((($Data | Where-Object {$_ -like "Features*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$ft = "$($_ -replace "[^a-z0-9]+")";if ($ft -ne "") {$Global:GlobalCPUInfo.Features.$ft = $true}}

                        if (-not $Global:GlobalCPUInfo.Name -or -not $Global:GlobalCPUInfo.Manufacturer) {
                            try {
                                $CPUimpl = [int]"$((($Data | Where-Object {$_ -match 'CPU implementer'} | Select-Object -First 1) -split ":")[1])".Trim()
                                if ($CPUimpl -gt 0) {
                                    $CPUpart = @($Data | Where-Object {$_ -match "CPU part"} | Foreach-Object {[int]"$(($_ -split ":")[1])".Trim()}) | Select-Object -Unique
                                    $CPUvariant = @($Data | Where-Object {$_ -match "CPU variant"} | Foreach-Object {[int]"$(($_ -split ":")[1])".Trim()}) | Select-Object -Unique
                                    $ArmDB = Get-Content ".\Data\armdb.json" | ConvertFrom-Json -ErrorAction Stop
                                    if ($ArmDB.implementers.$CPUimpl -ne $null) {
                                        $Global:GlobalCPUInfo.Manufacturer = $ArmDB.implementers.$CPUimpl
                                        $Global:GlobalCPUInfo.Name = "Unknown"

                                        if ($CPUpart.Length -gt 0) {
                                            $CPUName = @()
                                            for($i=0; $i -lt $CPUpart.Length; $i++) {
                                                $part = $CPUpart[$i]
                                                $variant = if ($CPUvariant -and $CPUvariant.length -gt $i) {$CPUvariant[$i]} else {$CPUvariant[0]}
                                                if ($ArmDB.variants.$CPUimpl.$part.$variant -ne $null) {$CPUName += $ArmDB.variants.$CPUimpl.$part.$variant}
                                                elseif ($ArmDB.parts.$CPUimpl.$part -ne $null) {$CPUName += $ArmDB.parts.$CPUimpl.$part}
                                            }
                                            if ($CPUName.Length -gt 0) {
                                                $Global:GlobalCPUInfo.Name = $CPUName -join "/"
                                                $Global:GlobalCPUInfo.Features.ARM = $true
                                            }
                                        }
                                    }
                                }
                            } catch {
                            }
                        }                

                        if ((-not $Global:GlobalCPUInfo.Name -or -not $Global:GlobalCPUInfo.Manufacturer -or -not $Processors) -and (Test-Path ".\Data\lscpu.txt")) {
                            try {
                                $lscpu = (Get-Content ".\Data\lscpu.txt") -split "[\r\n]+"
                                $CPUName = @($lscpu | Where-Object {$_ -match 'model name'} | Foreach-Object {"$(($_ -split ":")[1].Trim())"}) | Select-Object -Unique
                                $Global:GlobalCPUInfo.Name = $CPUName -join "/"
                                $Global:GlobalCPUInfo.Manufacturer = "$((($lscpu | Where-Object {$_ -match 'vendor id'}  | Select-Object -First 1) -split ":")[1])".Trim()
                                if (-not $Processors) {
                                    $Processors = [int]"$((($lscpu | Where-Object {$_ -match '^CPU\(s\)'}  | Select-Object -First 1) -split ":")[1])".Trim()
                                }

                                "$((($lscpu | Where-Object {$_ -like "flags*"} | Select-Object -First 1) -split ":")[1])".Trim() -split "\s+" | ForEach-Object {$Global:GlobalCPUInfo.Features."$($_ -replace "[^a-z0-9]+")" = $true}

                            } catch {
                            }
                        }

                        if ($Global:GlobalCPUInfo.PhysicalCPUs -gt 1) {
                            $Global:GlobalCPUInfo.Cores   *= $Global:GlobalCPUInfo.PhysicalCPUs
                            $Global:GlobalCPUInfo.Threads *= $Global:GlobalCPUInfo.PhysicalCPUs
                            $Global:GlobalCPUInfo.PhysicalCPUs = 1
                        }

                        #adapt to virtual CPUs and ARM
                        if ($Processors -gt $Global:GlobalCPUInfo.Threads -and $Global:GlobalCPUInfo.Threads -eq 1) {
                            $Global:GlobalCPUInfo.Cores   = $Processors
                            $Global:GlobalCPUInfo.Threads = $Processors
                        }
                    }
                }

                $Global:GlobalCPUInfo | Add-Member Vendor $(Switch -Regex ("$($Global:GlobalCPUInfo.Manufacturer)") {
                            "(AMD|Advanced Micro Devices)" {"AMD"}
                            "Hygon" {"HYGON"}
                            "Intel" {"INTEL"}
                            default {"$($Global:GlobalCPUInfo.Manufacturer)".ToUpper() -replace '\(R\)|\(TM\)|\(C\)' -replace '[^A-Z0-9]'}
                        })

                if (-not $Global:GlobalCPUInfo.Vendor) {$Global:GlobalCPUInfo.Vendor = "OTHER"}

                if ($Global:GlobalCPUInfo.Vendor -eq "ARM") {$Global:GlobalCPUInfo.Features.ARM = $true}

                if ($Global:GlobalCPUInfo.Features.avx512f -and $Global:GlobalCPUInfo.Features.avx512vl -and $Global:GlobalCPUInfo.Features.avx512dq -and $Global:GlobalCPUInfo.Features.avx512bw) {$Global:GlobalCPUInfo.Features.avx512 = $true}
                if ($Global:GlobalCPUInfo.Features.aesni) {$Global:GlobalCPUInfo.Features.aes = $true}
                if ($Global:GlobalCPUInfo.Features.shani) {$Global:GlobalCPUInfo.Features.sha = $true}

                if ($Global:GlobalCPUInfo.Vendor -eq "AMD" -or $Global:GlobalCPUInfo.Vendor -eq "HYGON") {
                    $zen = Switch ($Global:GlobalCPUInfo.Family) {
                        0x17 {
                            Switch ($Global:GlobalCPUInfo.Model) {
                                {$_ -in @(0x01,0x11,0x18,0x20)} {"zen";break}
                                {$_ -eq 0x08} {"zenplus";break}
                                {$_ -in @(0x31,0x47,0x60,0x68,0x71,0x90,0x98)} {"zen2";break}
                            }
                            break
                        }
                        0x18 {"zen";break}
                        0x19 {"zen3";break}
                    }
                    $f = $Global:GlobalCPUInfo.Features
                    if (-not $zen) {
                        $zen = if ($f.avx2 -and $f.sha -and $f.vaes) {"zen3"} elseif ($f.avx2 -and $f.sha -and $f.aes) {"zen"}
                    }
                    if ($zen) {
                        if ($f.avx2 -and $f.sha -and (($zen -eq "zen3" -and $f.vaes) -or ($zen -ne "zen3" -and $f.aes))) {$Global:GlobalCPUInfo.Features."is$($zen)" = $true}
                    }
                }

                $Global:GlobalCPUInfo | Add-Member RealCores ([int[]](0..($Global:GlobalCPUInfo.Threads - 1))) -Force
                if ($Global:GlobalCPUInfo.Threads -gt $Global:GlobalCPUInfo.Cores) {$Global:GlobalCPUInfo.RealCores = $Global:GlobalCPUInfo.RealCores | Where-Object {-not ($_ % [int]($Global:GlobalCPUInfo.Threads/$Global:GlobalCPUInfo.Cores))}}
            }
            $Global:GlobalCPUInfo | Add-Member IsRyzen ($Global:GlobalCPUInfo.Features.iszen -or $Global:GlobalCPUInfo.Features.iszenplus -or $Global:GlobalCPUInfo.Features.iszen2 -or $Global:GlobalCPUInfo.Features.iszen3 -or $Global:GlobalCPUInfo.Features.iszen4)

            if ($Script:CpuTDP -eq $null) {$Script:CpuTDP = Get-ContentByStreamReader ".\Data\cpu-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}
            
            $CpuName = $Global:GlobalCPUInfo.Name.Trim()
            if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {$CPU_tdp = 8}
            elseif (-not ($CPU_tdp = $Script:CpuTDP.PSObject.Properties | Where-Object {$CpuName -match $_.Name} | Select-Object -First 1 -ExpandProperty Value)) {$CPU_tdp = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}

            $Global:GlobalCPUInfo.TDP = $CPU_tdp
        }
        catch {
            Write-Log -Level Warn "CIM CPU detection has failed. "
        }
   
        try {
            for ($CPUIndex=0;$CPUIndex -lt $Global:GlobalCPUInfo.PhysicalCPUs;$CPUIndex++) {
                # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
                $Device = [PSCustomObject]@{
                    Name = ""
                    Index = [Int]$Index
                    Vendor = $Global:GlobalCPUInfo.Vendor
                    Vendor_Name = $Global:GlobalCPUInfo.Manufacturer
                    Type_PlatformId_Index = $CPUIndex
                    Type_Vendor_Index = $CPUIndex
                    Type = "Cpu"
                    Type_Index = $CPUIndex
                    Type_Mineable_Index = $CPUIndex
                    Type_Codec_Index = $CPUIndex
                    Model = "CPU"
                    Model_Base = "CPU"
                    Model_Name = $Global:GlobalCPUInfo.Name
                    Features = $Global:GlobalCPUInfo.Features.Keys
                    Data = [PSCustomObject]@{
                                Cores       = [int]($Global:GlobalCPUInfo.Cores / $Global:GlobalCPUInfo.PhysicalCPUs)
                                Threads     = [int]($Global:GlobalCPUInfo.Threads / $Global:GlobalCPUInfo.PhysicalCPUs)
                                CacheL3     = $Global:GlobalCPUInfo.L3CacheSize
                                Clock       = 0
                                Utilization = 0
                                PowerDraw   = 0
                                Temperature = 0
                                Method      = ""
                    }
                    DataMax = [PSCustomObject]@{
                                Clock       = 0
                                Utilization = 0
                                PowerDraw   = 0
                                Temperature = 0
                    }
                }

                $Device.Name = ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper()
                [void]$Global:GlobalCachedDevices.Add($Device)
                $Index++
            }
        }
        catch {
            Write-Log -Level Warn "CPU detection has failed. "
        }
    }

    $Global:GlobalCachedDevices | Foreach-Object {
        $Device = $_
        if (
            ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) -and
            ((-not $ExcludeName) -or (-not ($ExcludeName_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -and -not ($ExcludeName | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})))
            ) {
            $Device
        }
    }
}

function Get-DeviceName {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "AMD",
        [Parameter(Mandatory = $false)]
        [Bool]$UseAfterburner = $true
    )
    try {
        $Vendor_Cards = if (Test-Path ".\Data\$($Vendor.ToLower())-cards.json") {try {Get-ContentByStreamReader ".\Data\$($Vendor.ToLower())-cards.json" | ConvertFrom-Json -ErrorAction Stop}catch{}}

        if ($IsWindows -and $UseAfterburner -and $Script:abMonitor) {
            if ($Script:abMonitor) {$Script:abMonitor.ReloadAll()}
            $DeviceId = 0
            $Pattern = @{
                AMD    = '*Radeon*'
                NVIDIA = '*GeForce*'
                Intel  = '*Intel*'
            }
            @($Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor) | ForEach-Object {
                $DeviceName = Get-NormalizedDeviceName $_.Device -Vendor $Vendor
                $SubId = if ($_.GpuId -match "&DEV_([0-9A-F]+?)&") {$Matches[1]} else {"noid"}
                if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                [PSCustomObject]@{
                    Index      = $DeviceId
                    DeviceName = $DeviceName
                    InstanceId = $_.GpuId
                    SubId      = $SubId
                    PCIBusId   = if ($_.GpuId -match "&BUS_(\d+)&DEV_(\d+)") {"{0:x2}:{1:x2}" -f [int]$Matches[1],[int]$Matches[2]} else {$null}
                }
                $DeviceId++
            }
        } else {
            if ($IsWindows -and $Vendor -eq 'AMD') {

                $AdlStats = $null

                try {
                    $AdlResult = Invoke-Exe ".\Includes\odvii_$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}).exe" -WorkingDirectory $Pwd
                    if ($AdlResult -notmatch "Failed") {
                        $AdlStats = $AdlResult | ConvertFrom-Json -ErrorAction Stop
                    }
                } catch {
                }
                        
                if ($AdlStats -and $AdlStats.Count) {

                    $DeviceId = 0

                    $AdlStats | Foreach-Object {
                        $DeviceName = Get-NormalizedDeviceName $_."Adatper Name" -Vendor $Vendor
                        [PSCustomObject]@{
                            Index = $DeviceId
                            DeviceName = $DeviceName
                            SubId = 'noid'
                            PCIBusId = if ($_."Bus Id" -match "^([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                            CardId = -1
                        }
                        $DeviceId++
                    }
                }
            }

            if ($IsLinux -and $Vendor -eq 'AMD') {
                try {
                    $RocmInfo = [PSCustomObject]@{}
                    if (Get-Command "rocm-smi" -ErrorAction Ignore) {
                        $RocmFields = $false
                        Invoke-Exe "rocm-smi" -ArgumentList "--showhw" -ExpandLines -ExcludeEmptyLines | Where-Object {$_ -notmatch "==="} | Foreach-Object {
                            if (-not $RocmFields) {$RocmFields = $_ -split "\s\s+" | Foreach-Object {$_.Trim()};$GpuIx = $RocmFields.IndexOf("GPU");$BusIx = $RocmFields.IndexOf("BUS")} else {
                                $RocmVals = $_ -split "\s\s+" | Foreach-Object {$_.Trim()}
                                if ($RocmVals -and $RocmVals.Count -eq $RocmFields.Count -and $RocmVals[$BusIx] -match "([A-F0-9]+:[A-F0-9]+)\.") {
                                    $RocmInfo | Add-Member $($Matches[1] -replace "\.+$") $RocmVals[$GpuIx] -Force
                                }
                            }
                        }
                    }
                    $DeviceId = 0
                    $Cmd = if (Get-Command "amdmeminfo" -ErrorAction Ignore) {"amdmeminfo"} else {".\IncludesLinux\bin\amdmeminfo"}
                    Invoke-Exe $Cmd -ArgumentList "-o -q" -ExpandLines -Runas | Select-String "------", "Found Card:", "PCI:", "OpenCL ID", "Memory Model" | Foreach-Object {
                        Switch -Regex ($_) {
                            "------" {
                                $PCIdata = [PSCustomObject]@{
                                    Index      = $DeviceId
                                    DeviceName = ""
                                    SubId      = "noid"
                                    PCIBusId   = $null
                                    CardId     = -1
                                }
                                break
                            }
                            "Found Card:\s*[A-F0-9]{4}:([A-F0-9]{4}).+\((.+)\)" {$PCIdata.DeviceName = Get-NormalizedDeviceName $Matches[2] -Vendor $Vendor; $PCIdata.SubId = $Matches[1];break}
                            "Found Card:.+\((.+)\)" {$PCIdata.DeviceName = Get-NormalizedDeviceName $Matches[1] -Vendor $Vendor; break}
                            "OpenCL ID:\s*(\d+)" {$PCIdata.Index = [int]$Matches[1]; break}
                            "PCI:\s*([A-F0-9\:]+)" {$PCIdata.PCIBusId = $Matches[1] -replace "\.+$";if ($RocmInfo."$($PCIdata.PCIBusId)") {$PCIdata.CardId = [int]$RocmInfo."$($PCIdata.PCIBusId)"};break}
                            "Memory Model" {$PCIdata;$DeviceId++;break}
                        }
                    }
                } catch {
                    Write-Log -Level Warn "Call to amdmeminfo failed. Did you start as sudo or `"ocdaemon start`"?"
                }
            }

            if ($Vendor -eq "NVIDIA") {
                Invoke-NvidiaSmi "index","gpu_name","pci.device_id","pci.bus_id","driver_version" -CheckForErrors | ForEach-Object {
                    $DeviceName = $_.gpu_name.Trim()
                    $SubId = if ($AdlResultSplit.Count -gt 1 -and $AdlResultSplit[1] -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                    if ($Vendor_Cards -and $Vendor_Cards.$DeviceName.$SubId) {$DeviceName = $Vendor_Cards.$DeviceName.$SubId}
                    [PSCustomObject]@{
                        Index         = $_.index
                        DeviceName    = $DeviceName
                        SubId         = if ($_.pci_device_id -match "0x([A-F0-9]{4})") {$Matches[1]} else {"noid"}
                        PCIBusId      = if ($_.pci_bus_id -match ":([0-9A-F]{2}:[0-9A-F]{2})") {$Matches[1]} else {$null}
                        CardId        = -1
                        DriverVersion = "$($_.driver_version)"
                    }
                }
            }
        }
    } catch {
        Write-Log "Could not read GPU data for vendor $($Vendor). "
    }
}

#
# Device data update
#

function Update-DeviceInformation {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @(),
        [Parameter(Mandatory = $false)]
        [Bool]$UseAfterburner = $true,
        [Parameter(Mandatory = $false)]
        [PSCustomObject]$DeviceConfig = @{}        
    )
    $abReload = $true

    $PowerAdjust = @{}
    $Global:GlobalCachedDevices | Foreach-Object {
        $Model = $_.Model
        $PowerAdjust[$Model] = 100
        if ($DeviceConfig -and $DeviceConfig.$Model -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne $null -and $DeviceConfig.$Model.PowerAdjust -ne "") {$PowerAdjust[$Model] = $DeviceConfig.$Model.PowerAdjust}
    }

    if (-not (Test-Path "Variable:Global:GlobalGPUMethod")) {
        $Global:GlobalGPUMethod = @{}
    }

    $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "GPU" -and $DeviceName -icontains $_.Name} | Group-Object Vendor | Foreach-Object {
        $Devices = $_.Group
        $Vendor = $_.Name

        try { #AMD
            if ($Vendor -eq 'AMD') {

                if ($Script:AmdCardsTDP -eq $null) {$Script:AmdCardsTDP = Get-ContentByStreamReader ".\Data\amd-cards-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                $Devices | Foreach-Object {$_.Data.Method = "";$_.Data.Clock = $_.Data.ClockMem = $_.Data.FanSpeed = $_.Data.Temperature = $_.Data.PowerDraw = 0}

                if ($IsWindows) {

                    $Success = 0

                    foreach ($Method in @("Afterburner","odvii8")) {

                        if (-not $Global:GlobalGPUMethod.ContainsKey($Method)) {$Global:GlobalGPUMethod.$Method = ""}

                        if ($Global:GlobalGPUMethod.$Method -eq "fail") {Continue}
                        if ($Method -eq "Afterburner" -and -not ($UseAfterburner -and $Script:abMonitor -and $Script:abControl)) {Continue}

                        try {

                            Switch ($Method) {

                                "Afterburner" {
                                    #
                                    # try Afterburner
                                    #
                                    if ($abReload) {
                                        if ($Script:abMonitor) {$Script:abMonitor.ReloadAll()}
                                        if ($Script:abControl) {$Script:abControl.ReloadAll()}
                                        $abReload = $false
                                    }
                                    $DeviceId = 0
                                    $Pattern = @{
                                        AMD    = '*Radeon*'
                                        NVIDIA = '*GeForce*'
                                        Intel  = '*Intel*'
                                    }
                                    @($Script:abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Vendor) | ForEach-Object {
                                        $CardData    = $Script:abMonitor.Entries | Where-Object GPU -eq $_.Index
                                        $PowerLimitPercent = [int]$($Script:abControl.GpuEntries[$_.Index].PowerLimitCur)
                                        $Utilization = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage$").Data
                                        $PCIBusId    = if ($_.GpuId -match "&BUS_(\d+)&DEV_(\d+)") {"{0:x2}:{1:x2}" -f [int]$Matches[1],[int]$Matches[2]} else {$null}

                                        $Data = [PSCustomObject]@{
                                            Clock       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                                            ClockMem    = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                                            FanSpeed    = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                                            Temperature = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                                            PowerDraw   = $Script:AmdCardsTDP."$($_.Model_Name)" * ((100 + $PowerLimitPercent) / 100) * ($Utilization / 100)
                                        }

                                        $Devices | Where-Object {($_.BusId -and $PCIBusId -and ($_.BusId -eq $PCIBusId)) -or ((-not $_.BusId -or -not $PCIBusId) -and ($_.BusId_Type_Vendor_Index -eq $DeviceId))} | Foreach-Object {
                                            $NF = $_.Data.Method -eq ""
                                            $Changed = $false
                                            foreach($Value in @($Data.PSObject.Properties.Name)) {
                                                if ($NF -or $_.Data.$Value -le 0 -or ($Value -match "^Clock" -and $Data.$Value -gt 0)) {$_.Data.$Value = $Data.$Value;$Changed = $true}
                                            }

                                            if ($Changed) {
                                                $_.Data.Method = "$(if ($_.Data.Method) {";"})ab"
                                            }
                                        }
                                        $DeviceId++
                                    }
                                    if ($DeviceId) {
                                        $Global:GlobalGPUMethod.$Method = "ok"
                                        $Success++
                                    }
                                }

                                "odvii8" {
                                    #
                                    # try odvii8
                                    #

                                    $AdlStats = $null

                                    $AdlResult = Invoke-Exe ".\Includes\odvii_$(if ([System.Environment]::Is64BitOperatingSystem) {"x64"} else {"x86"}).exe" -WorkingDirectory $Pwd
                                    if ($AdlResult -notmatch "Failed") {
                                        $AdlStats = $AdlResult | ConvertFrom-Json -ErrorAction Stop
                                    }
                        
                                    if ($AdlStats -and $AdlStats.Count) {

                                        $DeviceId = 0

                                        $AdlStats | Foreach-Object {
                                            $CPstateMax = [Math]::Max([int]($_."Core P_States")-1,0)
                                            $MPstateMax = [Math]::Max([int]($_."Memory P_States")-1,0)
                                            $PCIBusId   = "$($_."Bus Id" -replace "\..+$")"

                                            $Data = [PSCustomObject]@{
                                                Clock       = [int]($_."Clock Defaults"."Clock P_State $CPstatemax")
                                                ClockMem    = [int]($_."Memory Defaults"."Clock P_State $MPstatemax")
                                                FanSpeed    = [int]($_."Fan Speed %")
                                                Temperature = [int]($_.Temperature)
                                                PowerDraw   = [int]($_.Wattage)
                                            }

                                            $Devices | Where-Object {($_.BusId -and $PCIBusId -and ($_.BusId -eq $PCIBusId)) -or ((-not $_.BusId -or -not $PCIBusId) -and ($_.BusId_Type_Vendor_Index -eq $DeviceId))} | Foreach-Object {
                                                $NF = $_.Data.Method -eq ""
                                                $Changed = $false
                                                foreach($Value in @($Data.PSObject.Properties.Name)) {
                                                    if ($NF -or $_.Data.$Value -le 0 -or ($Value -notmatch "^Clock" -and $Data.$Value -gt 0)) {$_.Data.$Value = $Data.$Value;$Changed = $true}
                                                }

                                                if ($Changed) {
                                                    $_.Data.Method = "$(if ($_.Data.Method) {";"})odvii8"
                                                }
                                            }

                                            $DeviceId++
                                        }
                                        if ($DeviceId) {
                                            $Global:GlobalGPUMethod.$Method = "ok"
                                            $Success++
                                        }
                                    }
                                }

                            }

                        } catch {
                        }

                        if ($Global:GlobalGPUMethod.$Method -eq "") {$Global:GlobalGPUMethod.$Method = "fail"}
                    }

                    if (-not $Success) {
                        Write-Log -Level Warn "Could not read power data from AMD"
                    }
                }
                elseif ($IsLinux) {

                    $AMD_Ok = $false
                    if (Get-Command "sensors" -ErrorAction Ignore) {

                        $sensorsJson = $null
                        try {
                            if (-not (Test-IsElevated) -and (Test-OCDaemon)) {
                                $sensorsJson = Invoke-OCDaemon -Cmd "sensors -j amdgpu-* 2>/dev/null" | ConvertFrom-Json -ErrorAction Stop
                            } else {
                                $sensorsJson = sensors -j amdgpu-* 2>$null | ConvertFrom-Json -ErrorAction Stop
                            }
                            if ($sensorsJson) {
                                $amdGPUs = @(
                                    $sensorsJson.PSObject.Properties.Name | Where-Object {$_ -match "^amdgpu-pci-([0-9a-f]{4})$"} | Foreach-Object {
                                        $gpu = $sensorsJson.$_
                                        $busHex = $matches[1]
                                        [PSCustomObject]@{
                                            BusId       = "$($busHex.Substring(0,2)):$($busHex.Substring(2,2))"
                                            Name        = $gpu.name
                                            Clock       = $gpu.gpu_clock_input
                                            ClockMem    = $gpu.mem_clock_input
                                            PowerDraw   = $gpu.power1_input
                                            Temperature = $gpu.temp1_input
                                            FanSpeed    = $gpu.fan1_input
                                        }
                                    } | Sort-Object -Property BusId
                                )

                                $DeviceId = 0
                                $amdGPUs | Foreach-Object {
                                    $gpu = $_
                                    $Devices | Where-Object {($_.BusId -and ($_.BusId -eq $gpu.BusId)) -or (-not $_.BusId -and ($DeviceId -eq $_.BusId_Vendor_Index))} | Foreach-Object {
                                        $_.Data.Clock       = [int]$gpu.Clock
                                        $_.Data.ClockMem    = [int]$gpu.ClockMem
                                        $_.Data.Temperature = [decimal]$gpu.Temperature
                                        $_.Data.PowerDraw   = [decimal]$gpu.PowerDraw
                                        $_.Data.FanSpeed    = [decimal]$gpu.FanSpeed
                                        $_.Data.Method      = "sensors"
                                        $AMD_Ok = $true
                                    }
                                    $DeviceId++
                                }
                            }

                        } catch {
                        }

                    }
                    
                    if (-not $AMD_Ok -and (Get-Command "rocm-smi" -ErrorAction Ignore)) {
                        try {
                            $Rocm = Invoke-Exe -FilePath "rocm-smi" -ArgumentList "-f -t -P --json" | ConvertFrom-Json -ErrorAction Ignore
                        } catch {
                        }

                        if ($Rocm) {
                            $DeviceId = 0

                            $Rocm.Psobject.Properties | Sort-Object -Property {[int]($_.Name -replace "[^\d]")} | Foreach-Object {
                                $Data = $_.Value
                                $Card = [int]($_.Name -replace "[^\d]")
                                $Devices | Where-Object {$_.CardId -eq $Card -or ($_.CardId -eq -1 -and $_.Type_Vendor_Index -eq $DeviceId)} | Foreach-Object {
                                    $_.Data.Temperature = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Temperature" -and $_.Name -notmatch "junction" -and $_.Value -match "[\d\.]+"} | Foreach-Object {[decimal]$_.Value} | Measure-Object -Average).Average
                                    $_.Data.PowerDraw   = [decimal]($Data.PSObject.Properties | Where-Object {$_.Name -match "Power" -and $_.Value -match "[\d\.]+"} | Select-Object -First 1).Value
                                    $_.Data.FanSpeed    = [int]($Data.PSObject.Properties | Where-Object {$_.Name -match "Fan.+%" -and $_.Value -match "[\d\.]+"} | Select-Object -First 1).Value
                                    $_.Data.Method      = "rocm"
                                }
                                $DeviceId++
                            }
                        }
                    }

                }
            }
        } catch {
            Write-Log -Level Warn "Could not read power data from AMD"
        }

        try { #INTEL
            if ($Vendor -eq 'INTEL') {

                if ($Script:IntelCardsTDP -eq $null) {$Script:IntelCardsTDP = Get-ContentByStreamReader ".\Data\intel-cards-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                $Devices | Foreach-Object {$_.Data.Method = "";$_.Data.Clock = $_.Data.ClockMem = $_.Data.FanSpeed = $_.Data.Temperature = $_.Data.PowerDraw = $_.Data.Utilization = 0}

                if ($IsWindows) {

                    #$Success = 0
                    #if (-not $Success) {
                    #    Write-Log -Level Warn "Could not read power data from INTEL"
                    #}
                }
                elseif ($IsLinux) {

                    $INTEL_Ok = $false

                    Get-ChildItem ".\IncludesLinux\bash" -Filter "sysinfo.sh" -File | Foreach-Object {

                        $intelJson = $null
                        try {
                            if (-not (Test-IsElevated) -and (Test-OCDaemon)) {
                                $intelJson = Invoke-OCDaemon -Cmd "$($_.FullName) --intel 2>/dev/null" | ConvertFrom-Json -ErrorAction Stop
                            } else {
                                $intelJson = Invoke-exe $_.FullName -ArgumentList "--intel" | ConvertFrom-Json -ErrorAction Stop
                            }
                            if ($intelJson.GPUs) {
                                $DeviceId = 0
                                $intelGPUs.GPUs | Foreach-Object {
                                    $gpu = $_
                                    $Devices | Where-Object {($_.BusId -and ($_.BusId -eq $gpu.BusId)) -or (-not $_.BusId -and ($DeviceId -eq $_.BusId_Vendor_Index))} | Foreach-Object {
                                        $_.Data.Clock       = [int]$gpu.Clock
                                        $_.Data.ClockMem    = [int]$gpu.ClockMem
                                        $_.Data.Temperature = [decimal]$gpu.Temperature
                                        $_.Data.PowerDraw   = [decimal]$gpu.PowerDraw
                                        $_.Data.FanSpeed    = [decimal]$gpu.FanSpeed
                                        $_.Data.Utilization = [decimal]$gpu.Utilization
                                        $_.Data.Method      = "sysinfo"
                                        $INTEL_Ok = $true

                                        if (-not $_.Data.PowerDraw -and $Script:IntelCardsTDP."$($_.Model_Name)") {$_.Data.PowerDraw = $Script:IntelCardsTDP."$($_.Model_Name)" * ([double]$_.Data.Utilization / 100)}
                                    }
                                    $DeviceId++
                                }
                            }

                        } catch {
                        }

                    }
                }
            }
        } catch {
            Write-Log -Level Warn "Could not read power data from INTEL"
        }

        try { #NVIDIA        
            if ($Vendor -eq 'NVIDIA') {
                #NVIDIA
                $DeviceId = 0
                if ($Script:NvidiaCardsTDP -eq $null) {$Script:NvidiaCardsTDP = Get-ContentByStreamReader ".\Data\nvidia-cards-tdp.json" | ConvertFrom-Json -ErrorAction Ignore}

                Invoke-NvidiaSmi "index","utilization.gpu","utilization.memory","temperature.gpu","power.draw","power.limit","fan.speed","pstate","clocks.current.graphics","clocks.current.memory","power.max_limit","power.default_limit" -CheckForErrors | ForEach-Object {
                    $Smi = $_
                    $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                        $_.Data.Utilization       = if ($smi.utilization_gpu -ne $null) {$smi.utilization_gpu} else {100}
                        $_.Data.UtilizationMem    = $smi.utilization_memory
                        $_.Data.Temperature       = $smi.temperature_gpu
                        $_.Data.PowerDraw         = $smi.power_draw
                        $_.Data.PowerLimit        = $smi.power_limit
                        $_.Data.FanSpeed          = $smi.fan_speed
                        $_.Data.Pstate            = $smi.pstate
                        $_.Data.Clock             = $smi.clocks_current_graphics
                        $_.Data.ClockMem          = $smi.clocks_current_memory
                        $_.Data.PowerMaxLimit     = $smi.power_max_limit
                        $_.Data.PowerDefaultLimit = $smi.power_default_limit
                        $_.Data.Method            = "smi"

                        if ($_.Data.PowerDefaultLimit) {$_.Data.PowerLimitPercent = [Math]::Floor(($_.Data.PowerLimit * 100) / $_.Data.PowerDefaultLimit)}
                        if (-not $_.Data.PowerDraw -and $Script:NvidiaCardsTDP."$($_.Model_Name)") {$_.Data.PowerDraw = $Script:NvidiaCardsTDP."$($_.Model_Name)" * ([double]$_.Data.PowerLimitPercent / 100) * ([double]$_.Data.Utilization / 100)}
                    }
                    $DeviceId++
                }
            }
        } catch {
            Write-Log -Level Warn "Could not read power data from NVIDIA"
        }

        try {
            $Devices | Foreach-Object {
                if ($_.Data.Clock -ne $null)       {$_.DataMax.Clock    = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)}
                if ($_.Data.ClockMem -ne $null)    {$_.DataMax.ClockMem = [Math]::Max([int]$_.DataMax.ClockMem,$_.Data.ClockMem)}
                if ($_.Data.Temperature -ne $null) {$_.DataMax.Temperature = [Math]::Max([decimal]$_.DataMax.Temperature,$_.Data.Temperature)}
                if ($_.Data.FanSpeed -ne $null)    {$_.DataMax.FanSpeed    = [Math]::Max([int]$_.DataMax.FanSpeed,$_.Data.FanSpeed)}
                if ($_.Data.PowerDraw -ne $null)   {
                    $_.Data.PowerDraw    *= ($PowerAdjust[$_.Model] / 100)
                    $_.DataMax.PowerDraw  = [Math]::Max([decimal]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                }
            }
        } catch {
            Write-Log -Level Warn "Could not calculate GPU maxium values"
        }
    }

    try { #CPU
        if (-not $DeviceName -or $DeviceName -like "CPU*") {
            $CPU_tdp = if ($Session.Config.PowerCPUtdp) {$Session.Config.PowerCPUtdp} else {$Global:GlobalCPUInfo.TDP}

            if (-not $Session.SysInfo.Cpus) {$Session.SysInfo = Get-SysInfo -IsARM $Session.IsARM -CPUtdp $CPU_tdp}

            if ($IsWindows) {
                $CPU_count = ($Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Measure-Object).Count
                $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    $Device = $_

                    $Session.SysInfo.Cpus | Select-Object -Index $Device.Type_Index | Foreach-Object {
                        $Device.Data.Clock       = [int]$_.Clock
                        $Device.Data.Utilization = [int]$_.Utilization
                        $Device.Data.PowerDraw   = [int]$_.PowerDraw
                        $Device.Data.Temperature = [int]$_.Temperature
                        $Device.Data.Method      = $_.Method
                    } 
                }
            }
            elseif ($IsLinux) {
                $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                    [int]$Utilization = [Math]::Min((((Invoke-Exe "ps" -ArgumentList "-A -o pcpu" -ExpandLines) -match "\d" | Measure-Object -Sum).Sum / $Global:GlobalCPUInfo.Threads), 100)

                    $_.Data.Clock       = [int]$(if ($Session.SysInfo.Cpus -and $Session.SysInfo.Cpus[0].Clock) {$Session.SysInfo.Cpus[0].Clock} else {$Global:GlobalCPUInfo.MaxClockSpeed})
                    $_.Data.Utilization = [int]$Utilization
                    $_.Data.PowerDraw   = [int]($CPU_tdp * $Utilization / 100)
                    $_.Data.Temperature = [int]$(if ($Session.SysInfo.Cpus -and $Session.SysInfo.Cpus[0].Temperature) {$Session.SysInfo.Cpus[0].Temperature} else {0})
                    $_.Data.Method      = "tdp"
                }
            }
            $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                $_.DataMax.Clock       = [Math]::Max([int]$_.DataMax.Clock,$_.Data.Clock)
                $_.DataMax.Utilization = [Math]::Max([int]$_.DataMax.Utilization,$_.Data.Utilization)
                $_.DataMax.PowerDraw   = [Math]::Max([int]$_.DataMax.PowerDraw,$_.Data.PowerDraw)
                $_.DataMax.Temperature = [Math]::Max([int]$_.DataMax.Temperature,$_.Data.Temperature)
            }
        }
    } catch {
        Write-Log -Level Warn "Could not read power data from CPU"
    }
}

#
# Afterburner functions
#

function Start-Afterburner {
    if (-not $IsWindows) {return}
    try {
        Add-Type -Path ".\Includes\MSIAfterburner.NET.dll"
    } catch {
        Write-Log "Failed to load Afterburner interface library"
        $Script:abMonitor = $false
        $Script:abControl = $false
        return
    }
   
    try {
        $Script:abMonitor = New-Object MSI.Afterburner.HardwareMonitor
    } catch {
        Write-Log "Failed to create MSI Afterburner Monitor object. Falling back to standard monitoring."
        $Script:abMonitor = $false
    }
    try {
        $Script:abControl = New-Object MSI.Afterburner.ControlMemory
    } catch {
        Write-Log "Failed to create MSI Afterburner Control object. Overclocking non-NVIDIA devices will not be available."
        $Script:abControl = $false
    }

    if ($Script:abControl) {
        $Script:abControlBackup = @($Script:abControl.GpuEntries | Select-Object Index,PowerLimitCur,ThermalLimitCur,CoreClockBoostCur,MemoryClockBoostCur)
    }
}

function Test-Afterburner {
    if (-not $IsWindows) {0}
    else {
        if (-not (Test-Path Variable:Script:abMonitor)) {return -1}
        if ($Script:abMonitor -and $Script:abControl) {1} else {0}
    }
}

function Get-AfterburnerDevices ($Type) {
    if (-not $Script:abControl) {return}

    try {
        $Script:abControl.ReloadAll()
    } catch {
        Write-Log -Level Warn "Failed to communicate with MSI Afterburner"
        return
    }

    if ($Type -in @('AMD', 'NVIDIA', 'INTEL')) {
        $Pattern = @{
            AMD    = "*Radeon*"
            NVIDIA = "*GeForce*"
            Intel  = "*Intel*"
        }
        @($Script:abMonitor.GpuEntries) | Where-Object Device -like $Pattern.$Type | ForEach-Object {
            $abIndex = $_.Index
            $Script:abMonitor.Entries | Where-Object {
                $_.GPU -eq $abIndex -and
                $_.SrcName -match "(GPU\d+ )?" -and
                $_.SrcName -notmatch "CPU"
            } | Format-Table
            @($Script:abControl.GpuEntries)[$abIndex]            
        }
        @($Script:abMonitor.GpuEntries)
    } elseif ($Type -eq 'CPU') {
        $Script:abMonitor.Entries | Where-Object {
            $_.GPU -eq [uint32]"0xffffffff" -and
            $_.SrcName -match "CPU"
        } | Format-Table
    }
}

#
# CPU device functions
#

function Get-CpuInfo {
    $family = 0
    $model  = 0
    $stepping = 0

    $features = @{}

    $info   = [CpuID]::Invoke(0)
    $vendor = [System.Text.Encoding]::ASCII.GetString($info[4..7]) + [System.Text.Encoding]::ASCII.GetString($info[12..15]) + [System.Text.Encoding]::ASCII.GetString($info[8..11])
    $nIds   = [BitConverter]::ToUInt32($info, 0)
    $nExIds = [BitConverter]::ToUInt32([CpuID]::Invoke(0x80000000), 0)

    $b1 = [Uint32]1
    $mask4bit = (($b1 -shl 4) -1)
    $mask8bit = (($b1 -shl 8) -1)

    If ($nIds -ge 0x00000001) { 

        $info = [CpuID]::Invoke(0x00000001)
        $info = [UInt32[]]@(
            [BitConverter]::ToUInt32($info, 0)
            [BitConverter]::ToUInt32($info, 4)
            [BitConverter]::ToUInt32($info, 8)
            [BitConverter]::ToUInt32($info, 12)
        )

        $features.mmx    = ($info[3] -band ($b1 -shl 23)) -ne 0
        $features.sse    = ($info[3] -band ($b1 -shl 25)) -ne 0
        $features.sse2   = ($info[3] -band ($b1 -shl 26)) -ne 0
        $features.sse3   = ($info[2] -band ($b1 -shl 00)) -ne 0
        $features.ssse3  = ($info[2] -band ($b1 -shl 09)) -ne 0
        $features.sse41  = ($info[2] -band ($b1 -shl 19)) -ne 0
        $features.sse42  = ($info[2] -band ($b1 -shl 20)) -ne 0
        $features.aes    = ($info[2] -band ($b1 -shl 25)) -ne 0
        $features.avx    = ($info[2] -band ($b1 -shl 28)) -ne 0
        $features.fma3   = ($info[2] -band ($b1 -shl 12)) -ne 0
        $features.rdrand = ($info[2] -band ($b1 -shl 30)) -ne 0

        $family = (($info[0] -shr 8) -band $mask4bit) + ($info[0] -shr 20) -band $mask8bit
        $model = (($info[0] -shr 4) -band $mask4bit) + ((($info[0] -shr 16) -band $mask4bit) -shl 4)
        $stepping = $info[0] -band $mask4bit
    }

    If ($nIds -ge 0x00000007) {
        $info = [CpuID]::Invoke(0x00000007)
        $info = [UInt32[]]@(
            [BitConverter]::ToUInt32($info, 0)
            [BitConverter]::ToUInt32($info, 4)
            [BitConverter]::ToUInt32($info, 8)
            [BitConverter]::ToUInt32($info, 12)
        )

        $features.avx2       = ($info[1] -band ($b1 -shl 05)) -ne 0
        $features.bmi1       = ($info[1] -band ($b1 -shl 03)) -ne 0
        $features.bmi2       = ($info[1] -band ($b1 -shl 08)) -ne 0
        $features.adx        = ($info[1] -band ($b1 -shl 19)) -ne 0
        $features.mpx        = ($info[1] -band ($b1 -shl 14)) -ne 0
        $features.sha        = ($info[1] -band ($b1 -shl 29)) -ne 0
        $features.avx512f    = ($info[1] -band ($b1 -shl 16)) -ne 0
        $features.avx512cd   = ($info[1] -band ($b1 -shl 28)) -ne 0
        $features.avx512pf   = ($info[1] -band ($b1 -shl 26)) -ne 0
        $features.avx512er   = ($info[1] -band ($b1 -shl 27)) -ne 0
        $features.avx512vl   = ($info[1] -band ($b1 -shl 31)) -ne 0
        $features.avx512bw   = ($info[1] -band ($b1 -shl 30)) -ne 0
        $features.avx512dq   = ($info[1] -band ($b1 -shl 17)) -ne 0
        $features.avx512ifma = ($info[1] -band ($b1 -shl 21)) -ne 0
        $features.avx512vbmi = ($info[2] -band ($b1 -shl 01)) -ne 0
        $features.vaes       = ($info[2] -band ($b1 -shl 09)) -ne 0
    }

    If ($nExIds -ge 0x80000001) { 
        $info = [CpuID]::Invoke(0x80000001)
        $info = [UInt32[]]@(
            [BitConverter]::ToUInt32($info, 0)
            [BitConverter]::ToUInt32($info, 4)
            [BitConverter]::ToUInt32($info, 8)
            [BitConverter]::ToUInt32($info, 12)
        )

        $features.x64   = ($info[3] -band ($b1 -shl 29)) -ne 0
        $features.abm   = ($info[2] -band ($b1 -shl 05)) -ne 0
        $features.sse4a = ($info[2] -band ($b1 -shl 06)) -ne 0
        $features.fma4  = ($info[2] -band ($b1 -shl 16)) -ne 0
        $features.xop   = ($info[2] -band ($b1 -shl 11)) -ne 0
    }

    [PSCustomObject]@{
        vendor   = $vendor
        family   = $family
        model    = $model
        stepping = $stepping
        features = $features.Keys.Where({$features.$_})
    }
}

#
# AMD Device functions
#

function Get-AMDComputeCapability {
    [CmdLetBinding()]
    param([string]$Model,[string]$Architecture = "")

    if ($Architecture -match "^(gfx\d+)") {
        $Architecture = $Matches[1]
    } else {
        $Architecture = "$($Architecture -replace ":.+$" -replace "[^A-Za-z0-9]+")"
    }

    try {
        if ($Script:AmdArchDB -eq $null) {$Script:AmdArchDB = Get-ContentByStreamReader ".\Data\amdarchdb.json" | ConvertFrom-Json -ErrorAction Ignore}

        foreach($Arch in $Script:AmdArchDB.PSObject.Properties) {
            $Arch_Match = $Arch.Value -join "|"
            if ($Model -match $Arch_Match -or $Architecture -match $Arch_Match) {
                return $Arch.Name
            }
        }
    } catch {
        Write-Log -Level Warn "No architecture found for AMD $($Model)/$($Architecture)"
    }
        
    $Architecture
}

function Reset-Vega {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [String[]]$DeviceName
)
    if (-not $IsWindows) {return}
    $Device = $Global:DeviceCache.DevicesByTypes.AMD | Where-Object {$DeviceName -icontains $_.Name -and $_.Model -match "Vega|RX\d{4}"}
    if ($Device) {
        $DeviceId   = $Device.Type_Vendor_Index -join ','
        $PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId
        $Arguments = "--opencl $($PlatformId) --gpu $($DeviceId) --hbcc %onoff% --admin fullrestart"
        try {
            Invoke-Exe ".\Includes\switch-radeon-gpu.exe" -ArgumentList ($Arguments -replace "%onoff%","on") -AutoWorkingDirectory >$null
            Start-Sleep 1
            Invoke-Exe ".\Includes\switch-radeon-gpu.exe" -ArgumentList ($Arguments -replace "%onoff%","off") -AutoWorkingDirectory >$null
            Start-Sleep 1
            Write-Log "Disabled/Enabled device(s) $DeviceId"
        } catch {
            Write-Log "Failed to disable/enable device(s) $($DeviceId): $($_.Exception.Message)"
        }
    }
}

#
# NVIDIA Device functions
#

function Get-NvidiaArchitecture {
    [CmdLetBinding()]
    param([string]$Model,[string]$ComputeCapability = "")
    $ComputeCapability = $ComputeCapability -replace "[^\d\.]"

    try {
        if ($Script:NvidiaArchDB -eq $null) {$Script:NvidiaArchDB = Get-ContentByStreamReader ".\Data\nvidiaarchdb.json" | ConvertFrom-Json -ErrorAction Ignore}

        foreach($Arch in $Script:NvidiaArchDB.PSObject.Properties) {
            if ($ComputeCapability -in $Arch.Value.Compute) {
                return $Arch.Name
            }
        }

        foreach($Arch in $Script:NvidiaArchDB.PSObject.Properties) {
            $Model_Match = $Arch.Value.Model -join "|"
            if ($Model -match $Model_Match) {
                return $Arch.Name
            }
        }

    } catch {
        Write-Log -Level Warn "No architecture found for Nvidia $($Model)/$($ComputeCapability)"
    }
    "Other"
}

function Get-NvidiaSmi {
    $Command =  if ($IsLinux) {"nvidia-smi"}
                elseif ($Session.Config.NVSMIpath -and (Test-Path ($NVSMI = Join-Path $Session.Config.NVSMIpath "nvidia-smi.exe"))) {$NVSMI}
                elseif ($Session.DefaultValues.NVSMIpath -and (Test-Path ($NVSMI = Join-Path $Session.DefaultValues.NVSMIpath "nvidia-smi.exe"))) {$NVSMI}
                else {".\Includes\nvidia-smi.exe"}
    if (Get-Command $Command -ErrorAction Ignore) {$Command}
}

function Invoke-NvidiaSmi {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $False)]
    [String[]]$Query = @(),
    [Parameter(Mandatory = $False)]
    [String[]]$Arguments = @(),
    [Parameter(Mandatory = $False)]
    [Switch]$Runas,
    [Parameter(Mandatory = $False)]
    [Switch]$CheckForErrors
)

    if (-not ($NVSMI = Get-NvidiaSmi)) {return}

    $ArgumentsString = "$($Arguments -join ' ')"

    if ($CheckForErrors -and $ArgumentsString -notmatch "-i ") {
        if (-not (Test-Path Variable:Global:GlobalNvidiaSMIList)) {
            $Global:GlobalNvidiaSMIList = @(Invoke-NvidiaSmi -Arguments "--list-gpus" | Foreach-Object {if ($_ -match "UUID:\s+([A-Z0-9\-]+)") {$Matches[1]} else {"error"}} | Select-Object)
        }
        $DeviceId = 0
        $GoodDevices = $Global:GlobalNvidiaSMIList | Foreach-Object {if ($_ -ne "error") {$DeviceId};$DeviceId++}
        $Arguments += "-i $($GoodDevices -join ",")"
        $SMI_Result = Invoke-NvidiaSmi -Query $Query -Arguments $Arguments -Runas:$Runas
        $DeviceId = 0
        $Global:GlobalNvidiaSMIList | Foreach-Object {
            if ($_ -ne "error") {$SMI_Result[$DeviceId];$DeviceId++}
            else {[PSCustomObject]@{}}
        }
    } else {

        if ($Query) {
            $ArgumentsString = "$ArgumentsString --query-gpu=$($Query -join ',') --format=csv,noheader,nounits"
            $CsvParams =  @{Header = @($Query | Foreach-Object {$_ -replace "[^a-z_-]","_" -replace "_+","_"} | Select-Object)}
            Invoke-Exe -FilePath $NVSMI -ArgumentList $ArgumentsString.Trim() -ExcludeEmptyLines -ExpandLines -Runas:$Runas | ConvertFrom-Csv @CsvParams | Foreach-Object {
                $obj = $_
                $obj.PSObject.Properties.Name | Foreach-Object {
                    $v = $obj.$_
                    if ($v -match '(error|supported)') {$v = $null}
                    elseif ($_ -match "^(clocks|fan|index|memory|temperature|utilization)") {
                        $v = $v -replace "[^\d\.]"
                        if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") {$v = $null}
                        else {$v = [int]$v}
                    }
                    elseif ($_ -match "^(power)") {
                        $v = $v -replace "[^\d\.]"
                        if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") {$v = $null}
                        else {$v = [double]$v}
                    }
                    $obj.$_ = $v
                }
                $obj
            }
        } else {
            if ($IsLinux -and $Runas) {
                Set-OCDaemon "$NVSMI $ArgumentsString" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
            } else {
                Invoke-Exe -FilePath $NVSMI -ArgumentList $ArgumentsString -ExcludeEmptyLines -ExpandLines -Runas:$Runas
            }
        }
    }
}

function Invoke-NvidiaSettings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$NvCmd = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$SetPowerMizer
    )
    if ($IsLinux) {
        $Cmd = "$($NvCmd -join ' ')"
        if ($SetPowerMizer) {
            Get-Device "nvidia" | Select-Object -ExpandProperty Type_Vendor_index | Foreach-Object {$Cmd = "$Cmd -a '[gpu:$($_)]/GPUPowerMizerMode=1'"}
        }
        $Cmd = $Cmd.Trim()
        if ($Cmd) {
            Set-OCDaemon "nvidia-settings $Cmd" -OnEmptyAdd $Session.OCDaemonOnEmptyAdd
        }
    } elseif ($IsWindows -and $NvCmd) {
        (Start-Process ".\Includes\NvidiaInspector\nvidiaInspector.exe" -ArgumentList "$($NvCmd -join " ")" -PassThru).WaitForExit(1000) > $null
        #& ".\Includes\NvidiaInspector\nvidiaInspector.exe" $NvCmd
    }
}

function Set-NvidiaPowerLimit {
[cmdletbinding()]   
param(
    [Parameter(Mandatory = $True)]
    [Int[]]$Device,
    [Parameter(Mandatory = $true)]
    [Int[]]$PowerLimitPercent

)
    if (-not $PowerLimitPercent.Count -or -not $Device.Count) {return}
    try {
        for($i=0;$i -lt $Device.Count;$i++) {$Device[$i] = [int]$Device[$i]}
        Invoke-NvidiaSmi "index","power.default_limit","power.min_limit","power.max_limit","power.limit" -Arguments "-i $($Device -join ',')" | Where-Object {$_.index -match "^\d+$"} | Foreach-Object {
            $index = $Device.IndexOf([int]$_.index)
            if ($index -ge 0) {
                $PLim = [Math]::Round([double]($_.power_default_limit -replace '[^\d,\.]')*($PowerLimitPercent[[Math]::Min($index,$PowerLimitPercent.Count)]/100),2)
                $PCur = [Math]::Round([double]($_.power_limit -replace '[^\d,\.]'))
                if ($lim = [int]($_.power_min_limit -replace '[^\d,\.]')) {$PLim = [Math]::Max($PLim, $lim)}
                if ($lim = [int]($_.power_max_limit -replace '[^\d,\.]')) {$PLim = [Math]::Min($PLim, $lim)}
                if ($PLim -ne $PCur) {
                    Invoke-NvidiaSmi -Arguments "-i $($_.index)","-pl $($Plim.ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture))" -Runas > $null
                }
            }
        }
    } catch {}
}

#
# General functions
#

function Get-GPUVendorList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$Type = @() #AMD/INTEL/NVIDIA
    )
    if (-not $Type.Count) {$Type = "AMD","INTEL","NVIDIA"}
    $Type | Foreach-Object {if ($_ -like "*AMD*" -or $_ -like "*Advanced Micro*"){"AMD","Advanced Micro Devices","Advanced Micro Devices, Inc."}elseif($_ -like "*NVIDIA*" ){"NVIDIA","NVIDIA Corporation"}elseif($_ -like "*INTEL*"){"INTEL","Intel(R) Corporation","GenuineIntel"}else{$_}} | Select-Object -Unique
}

function Get-GPUIDs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject[]]$Devices,
        [Parameter(Mandatory = $False)]
        [Int]$Offset = 0,
        [Parameter(Mandatory = $False)]
        [Switch]$ToHex = $False,
        [Parameter(Mandatory = $False)]
        [String]$Join
    )
    $GPUIDs = $Devices | Select -ExpandProperty Type_PlatformId_Index -ErrorAction Ignore | Foreach-Object {if ($ToHex) {[Convert]::ToString($_ + $Offset,16)} else {$_ + $Offset}}
    if ($PSBoundParameters.ContainsKey("Join")) {$GPUIDs -join $Join} else {$GPUIDs}    
}

function Get-DevicePowerDraw {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @()
    )
    (($Global:GlobalCachedDevices | Where-Object {-not $DeviceName -or $DeviceName -icontains $_.Name}).Data.PowerDraw | Measure-Object -Sum).Sum
}

function Get-NormalizedDeviceName {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$DeviceName,
        [Parameter(Mandatory = $false)]
        [String]$Vendor = "AMD"
    )

    $DeviceName = "$($DeviceName -replace '\([A-Z0-9 ]+\)?')"

    if ($Vendor -eq "AMD") {
        $DeviceName = "$($DeviceName `
                -replace 'ASUS' `
                -replace 'AMD' `
                -replace 'Series' `
                -replace 'Graphics' `
                -replace 'Adapter' `
                -replace '\d+GB$' `
                -replace "\s+", ' '
        )".Trim()

        if ($DeviceName -match '.*\s(HD)\s?(\w+).*') {"Radeon HD $($Matches[2])"}                 # HD series
        elseif ($DeviceName -match '.*\s(Vega).*(56|64).*') {"Radeon Vega $($Matches[2])"}        # Vega series
        elseif ($DeviceName -match '.*\s(R\d)\s(\w+).*') {"Radeon $($Matches[1]) $($Matches[2])"} # R3/R5/R7/R9 series
        elseif ($DeviceName -match '.*Radeon.*(5[567]00[\w\s]*)') {"Radeon RX $($Matches[1])"}         # RX 5000 series
        elseif ($DeviceName -match '.*Radeon.*([4-5]\d0).*') {"Radeon RX $($Matches[1])"}         # RX 400/500 series
        else {$DeviceName}
    } elseif ($Vendor) {
        "$($DeviceName `
                -replace $Vendor `
                -replace "\s+", ' '
        )".Trim()
    } else {
        "$($DeviceName `
                -replace "\s+", ' '
        )".Trim()
    }
}

function Select-Device {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $False)]
        [Array]$Devices = @(),
        [Parameter(Mandatory = $False)]
        [Array]$Type = @(), #CPU/AMD/NVIDIA
        [Parameter(Mandatory = $False)]
        [Long]$MinMemSize = 0
    )
    $Devices | Where-Object {($_.Type -eq "CPU" -and $Type -contains "CPU") -or ($_.Type -eq "GPU" -and $_.OpenCL.GlobalMemsize -ge $MinMemSize -and $Type -icontains $_.Vendor)}
}

function Get-DeviceModelName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        $Device,
        [Parameter(Mandatory = $False)]
        [Array]$Name = @(),
        [Parameter(Mandatory = $False)]
        [Switch]$Short
    )
    $Device | Where-Object {$Name.Count -eq 0 -or $Name -icontains $_.Name} | Foreach-Object {if ($_.Type -eq "Cpu") {"CPU"} else {$_.Model_Name}} | Select-Object -Unique | Foreach-Object {if ($Short){($_ -replace "geforce|radeon|intel|\(r\)","").Trim()}else {$_}}
}

function Test-GPU {
    #$VideoCardsAvail = Get-GPUs
    $GPUfail = 0
    #Get-GPUobjects | Foreach-Object { if ( $VideoCardsAvail.DeviceID -notcontains $_.DeviceID ) { $GPUfail++ } }
    if ($GPUfail -ge 1) {
        Write-Log -Level Error "$($GPUfail) failing GPU(s)! PC will reboot in 5 seconds"
        Start-Sleep 5
        $reboot = @("-r", "-f", "-t", 0)
        & shutdown $reboot        
    }
}

function Get-DeviceSubsets($Device) {
    $Models = @($Device | Select-Object Model,Model_Name -Unique)
    if ($Models.Count) {
        [System.Collections.Generic.List[string]]$a = @();0..$($Models.Count-1) | Foreach-Object {[void]$a.Add('{0:x}' -f $_)}
        @(Get-Subsets $a | Where-Object {$_.Length -gt 1} | Foreach-Object{
            [PSCustomObject[]]$x = @($_.ToCharArray() | Foreach-Object {$Models[[int]"0x$_"]}) | Sort-Object -Property Model
            [PSCustomObject]@{
                Model = @($x.Model)
                Model_Name = @($x.Model_Name)
                Name = @($Device | Where-Object {$x.Model -icontains $_.Model} | Select-Object -ExpandProperty Name -Unique | Sort-Object)
            }
        })
    }
}

function Get-Subsets($a){
    #uncomment following to ensure only unique inputs are parsed
    #e.g. 'B','C','D','E','E' would become 'B','C','D','E'
    $a = $a | Select-Object -Unique
    #create an array to store output
    [System.Collections.ArrayList]$l = @()
    #for any set of length n the maximum number of subsets is 2^n
    for ($i = 0; $i -lt [Math]::Pow(2,$a.Length); $i++)
    { 
        #temporary array to hold output
        [string[]]$out = New-Object string[] $a.length
        #iterate through each element
        for ($j = 0; $j -lt $a.Length; $j++)
        { 
            #start at the end of the array take elements, work your way towards the front
            if (($i -band (1 -shl ($a.Length - $j - 1))) -ne 0)
            {
                #store the subset in a temp array
                $out[$j] = $a[$j]
            }
        }
        #stick subset into an array
        [void]$l.Add(-join $out)
    }
    #group the subsets by length, iterate through them and sort
    $l | Group-Object -Property Length | %{$_.Group | sort}
}