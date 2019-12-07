using module .\Include.psm1

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

Init-Session

function Get-DeviceDebug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$Name = @(),
        [Parameter(Mandatory = $false)]
        [Switch]$Refresh = $false
    )

    if ($Name) {
        if (-not (Test-Path Variable:Global:GlobalDataDeviceList) -or -not $Global:GlobalDataDeviceList) {$Global:GlobalDataDeviceList = Get-Content ".\Data\devices.json" -Raw | ConvertFrom-Json}        
        $Name_Devices = $Name | ForEach-Object {
            $Name_Split = $_ -split '#'
            $Name_Split = @($Name_Split | Select-Object -First 1) + @($Name_Split | Select-Object -Skip 1 | ForEach-Object {[Int]$_})
            $Name_Split += @("*") * (100 - $Name_Split.Count)

            $Name_Device = $Global:GlobalDataDeviceList.("{0}" -f $Name_Split) | Select-Object *
            $Name_Device | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | ForEach-Object {$Name_Device.$_ = $Name_Device.$_ -f $Name_Split}

            $Name_Device
        }
    }

    # Try to get cached devices first to improve performance
    if ((Test-Path Variable:Global:GlobalCachedDevices) -and -not $Refresh) {
        $Global:GlobalCachedDevices | Foreach-Object {
            $Device = $_
            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_})) {
                $Device
            }
        }
        return
    }

    $Devices = @()
    $PlatformId = 0
    $Index = 0
    $PlatformId_Index = @{}
    $Type_PlatformId_Index = @{}
    $Vendor_Index = @{}
    $Type_Vendor_Index = @{}
    $Type_Index = @{}
    $Type_Mineable_Index = @{}
    $GPUVendorLists = @{}
    foreach ($GPUVendor in @("NVIDIA","AMD","INTEL")) {$GPUVendorLists | Add-Member $GPUVendor @(Get-GPUVendorList $GPUVendor)}

    try {
        [OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
            [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All) | ForEach-Object {
                $Device_OpenCL = $_ | ConvertTo-Json | ConvertFrom-Json

                $Device_Name = [String]$Device_OpenCL.Name -replace '\(TM\)|\(R\)'
                $Vendor_Name = [String]$Device_OpenCL.Vendor

                if ($GPUVendorLists.NVIDIA -icontains $Vendor_Name) {
                    $Vendor_Name = "NVIDIA"
                } elseif ($GPUVendorLists.AMD -icontains $Vendor_Name) {
                    $Device_Name = $($Device_Name -replace 'ASUS|AMD|Series|Graphics' -replace "\s+", ' ').Trim()
                    $Device_Name = $Device_Name -replace '.*Radeon.*([4-5]\d0).*', 'Radeon RX $1'     # RX 400/500 series
                    $Device_Name = $Device_Name -replace '.*\s(Vega).*(56|64).*', 'Radeon Vega $2'    # Vega series
                    $Device_Name = $Device_Name -replace '.*\s(R\d)\s(\w+).*', 'Radeon $1 $2'         # R3/R5/R7/R9 series
                    $Device_Name = $Device_Name -replace '.*\s(HD)\s?(\w+).*', 'Radeon HD $2'         # HD series
                    $Vendor_Name = "AMD"
                } elseif ($GPUVendorLists.INTEL -icontains $Vendor_Name) {
                    $Vendor_Name = "INTEL"
                }

                $Device = [PSCustomObject]@{
                    Index = [Int]$Index
                    PlatformId = [Int]$PlatformId
                    PlatformId_Index = [Int]$PlatformId_Index."$($PlatformId)"
                    Type_PlatformId_Index = [Int]$Type_PlatformId_Index."$($Device_OpenCL.Type)"."$($PlatformId)"
                    Vendor = [String]$Vendor_Name
                    Vendor_Name = [String]$Device_OpenCL.Vendor                    
                    Vendor_Index = [Int]$Vendor_Index."$($Device_OpenCL.Vendor)"
                    Type_Vendor_Index = [Int]$Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"
                    Type = [String]$Device_OpenCL.Type
                    Type_Index = [Int]$Type_Index."$($Device_OpenCL.Type)"
                    Type_Mineable_Index = [Int]$Type_Mineable_Index."$($Device_OpenCL.Type)"
                    OpenCL = $Device_OpenCL
                    Model = [String]$($Device_Name -replace "[^A-Za-z0-9]+" -replace "GeForce|Radeon|Intel")
                    Model_Name = [String]$Device_Name
                }

                if ($Device.Type -ne "Cpu" -and ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))}) -or ($Name | Where-Object {@($Device.Model,$Device.Model_Name) -like $_}))) {
                    $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
                    $Index++
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
                $Type_Vendor_Index."$($Device_OpenCL.Type)"."$($Device_OpenCL.Vendor)"++
                $Type_Index."$($Device_OpenCL.Type)"++
                if (@("NVIDIA","AMD") -icontains $Vendor_Name) {$Type_Mineable_Index."$($Device_OpenCL.Type)"++}
            }

            $PlatformId++
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Host "OpenCL device detection has failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    #CPU detection
    try {$CPUFeatures = $($feat = @{}; switch -regex ((& .\Includes\CHKCPU32.exe /x) -split "</\w+>") {"^\s*<_?(\w+)>(\d+).*" {$feat.($matches[1]) = [int]$matches[2]}}; $feat)} catch {if ($Error.Count){$Error.RemoveAt(0)}}
    try {
        if (-not (Test-Path Variable:Global:GlobalGetDeviceCacheCIM)) {$Global:GlobalGetDeviceCacheCIM = Get-CimInstance -ClassName CIM_Processor}
        if (-not (Test-Path Variable:CPUFeatures)) {
            $CPUFeatures = [PSCustomObject]@{
                physical_cpus = $Global:GlobalGetDeviceCacheCIM.Count
                cores = ($Global:GlobalGetDeviceCacheCIM.NumberOfCores | Measure-Object -Sum).Sum
                threads = ($Global:GlobalGetDeviceCacheCIM.NumberOfLogicalProcessors | Measure-Object -Sum).Sum
                tryall = 1
            }
        }
    }
    catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Host "CIM CPU detection has failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        $CPURealCores = [int[]](0..($CPUFeatures.threads - 1))
        $CPUVendor = if ($GPUVendorLists.INTEL -icontains $Global:GlobalGetDeviceCacheCIM[0].Manufacturer){"INTEL"}else{$Global:GlobalGetDeviceCacheCIM[0].Manufacturer.ToUpper()}
        if ($CPUVendor -eq "INTEL" -and $CPUFeatures.threads -gt $CPUFeatures.cores) {$CPURealCores = $CPURealCores | Where-Object {-not ($_ % [int]($CPUFeatures.threads/$CPUFeatures.cores))}}

        $CPUIndex = $PhysicalCPUIndex = 0

        foreach ($CPURealCore in @($CPURealCores)) {
            # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
            $CIM = $Global:GlobalGetDeviceCacheCIM[$PhysicalCPUIndex] | ConvertTo-Json | ConvertFrom-Json

            $Device = [PSCustomObject]@{
                Index = [Int]$Index
                Vendor = $CPUVendor
                Vendor_Name = $CIM.Manufacturer
                Type_PlatformId_Index = $PhysicalCPUIndex
                Type_Vendor_Index = $PhysicalCPUIndex
                Type = "Cpu"
                Type_Index = $CPUIndex
                CPU_Thread = $CPURealCore
                CPU_Affinity = 1 -shl $CPURealCore
                CPU_Features = $CPUFeatures
                CIM = $Global:GlobalGetDeviceCacheCIM[$PhysicalCPUIndex] | ConvertTo-Json | ConvertFrom-Json
                Model = "CPU"
                Model_Name = $CIM.Name
            }

            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.CPU_Thread).ToUpper() -PassThru
            }

            if ($CPURealCore -gt 0 -and -not ($CPURealCore % ($CPUFeatures.threads/$CPUFeatures.physical_cpus))) {$PhysicalCPUIndex++}
            $CPUIndex++
            $Index++
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Host "CIM CPU detection has failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    $Global:GlobalCachedDevices = $Devices
    $Devices
}

function Update-DeviceInformationDebug {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String[]]$DeviceName = @(),
        [Parameter(Mandatory = $false)]
        [Bool]$UseAfterburner = $true        
    )
    
    $abReload = $true

    $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "GPU" -and $DeviceName -icontains $_.Name} | Group-Object Vendor | Foreach-Object {
        $Devices = $_.Group
        $Vendor = $_.Name
        
        try { #AMD
            if ($UseAfterburner -and $Script:abMonitor -and $Vendor -eq "AMD") {
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
                    $CardData = $Script:abMonitor.Entries | Where-Object GPU -eq $_.Index
                    $AdapterId = $_.Index

                    $Devices | Where-Object {$_.Vendor -eq $Vendor -and $_.Type_Vendor_Index -eq $DeviceId} | Foreach-Object {
                        $_ | Add-Member Data ([PSCustomObject]@{
                                AdapterId         = [int]$AdapterId
                                Utilization       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage$").Data
                                UtilizationMem    = [int]$($mem = $CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage$"; if ($mem.MaxLimit) {$mem.Data / $mem.MaxLimit * 100})
                                Clock             = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock$").Data
                                ClockMem          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock$").Data
                                FanSpeed          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed$").Data
                                Temperature       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature$").Data
                                PowerDraw         = [int]$($CardData | Where-Object {$_.SrcName -match "^(GPU\d* )?power$" -and $_.SrcUnits -eq 'W'}).Data
                                PowerLimitPercent = [int]$($abControl.GpuEntries[$_.Index].PowerLimitCur)
                                #PCIBus            = [int]$($null = $_.GpuId -match "&BUS_(\d+)&"; $matches[1])
                                Method            = "ab"
                            }) -Force
                    }
                    $DeviceId++
                }
            } else {

                if ($Vendor -eq 'AMD') {
                    #AMD
                    $DeviceId = 0
                    $Command = ".\Includes\OverdriveN.exe"
                    $AdlResult = & $Command | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed" -and $_ -ne "Failed to load ADL library"}
                    if (-not (Test-Path Variable:Script:AmdCardsTDP)) {$Script:AmdCardsTDP = Get-Content ".\Data\amd-cards-tdp.json" -Raw | ConvertFrom-Json}

                    if ($null -ne $AdlResult) {
                        $AdlResult | ForEach-Object {
                            [System.Collections.ArrayList]$AdlResultSplit = @('noid',0,1,0,0,100,0,0,'')
                            $i=0
                            foreach($v in @($_ -split ',')) {
                                if ($i -ge $AdlResultSplit.Count) {break}
                                if ($i -eq 0) {
                                    $AdlResultSplit[0] = $v
                                } elseif ($i -eq 8) {
                                    $AdlResultSplit[8] = $($v `
                                            -replace 'ASUS' `
                                            -replace 'AMD' `
                                            -replace '\(?TM\)?' `
                                            -replace 'Series' `
                                            -replace 'Graphics' `
                                            -replace "\s+", ' '
                                    ).Trim()

                                    $AdlResultSplit[8] = $AdlResultSplit[8] -replace '.*Radeon.*([4-5]\d0).*', 'Radeon RX $1'     # RX 400/500 series
                                    $AdlResultSplit[8] = $AdlResultSplit[8] -replace '.*\s(Vega).*(56|64).*', 'Radeon Vega $2'    # Vega series
                                    $AdlResultSplit[8] = $AdlResultSplit[8] -replace '.*\s(R\d)\s(\w+).*', 'Radeon $1 $2'         # R3/R5/R7/R9 series
                                    $AdlResultSplit[8] = $AdlResultSplit[8] -replace '.*\s(HD)\s?(\w+).*', 'Radeon HD $2'         # HD series
                                } elseif ($i -lt 8) {
                                    $v = $v -replace "[^\d\.]"
                                    if ($v -match "^(\d+|\.\d+|\d+\.\d+)$") {
                                        $ibak = $AdlResultSplit[$i]
                                        try {
                                            if ($i -eq 5 -or $i -eq 7){$AdlResultSplit[$i]=[double]$v}else{$AdlResultSplit[$i]=[int]$v}
                                        } catch {
                                            if ($Error.Count){$Error.RemoveAt(0)}
                                            $AdlResultSplit[$i] = $ibak
                                        }
                                    }
                                }
                                $i++
                            }
                            if (-not $AdlResultSplit[2]) {$AdlResultSplit[1]=0;$AdlResultSplit[2]=1}
                            $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                                $_ | Add-Member Data ([PSCustomObject]@{
                                        AdapterId         = $AdlResultSplit[0]
                                        FanSpeed          = [int]($AdlResultSplit[1] / $AdlResultSplit[2] * 100)
                                        Clock             = [int]($AdlResultSplit[3] / 100)
                                        ClockMem          = [int]($AdlResultSplit[4] / 100)
                                        Utilization       = [int]$AdlResultSplit[5]
                                        Temperature       = [int]$AdlResultSplit[6] / 1000
                                        PowerLimitPercent = 100 + [int]$AdlResultSplit[7]
                                        PowerDraw         = $Script:AmdCardsTDP."$(if ($AdlResultSplit[8]){$AdlResultSplit[8]}else{$_.Model_Name})" * ((100 + $AdlResultSplit[7]) / 100) * ($AdlResultSplit[5] / 100)
                                        Method            = "tdp"
                                    }) -Force
                            }
                            $DeviceId++
                        }
                    }
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Host "Could not read power data from AMD: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try { #NVIDIA        
            if ($Vendor -eq 'NVIDIA') {
                #NVIDIA
                $DeviceId = 0
                $Command = '.\includes\nvidia-smi.exe'
                $Arguments = @(
                    '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
                    '--format=csv,noheader'
                )
                if (-not (Test-Path Variable:Script:NvidiaCardsTDP)) {$Script:NvidiaCardsTDP = Get-Content ".\Data\nvidia-cards-tdp.json" -Raw | ConvertFrom-Json}
                & $Command $Arguments | ForEach-Object {
                    $SMIresultSplit = $_ -split ','
                    if ($SMIresultSplit.count -gt 10) {
                        for($i = 1; $i -lt $SMIresultSplit.count; $i++) {
                            $v = $SMIresultSplit[$i].Trim()
                            if ($v -match '(error|supported)') {$v = "-"}
                            elseif ($i -ne 7) {
                                $v = $v -replace "[^\d\.]"
                                if ($v -notmatch "^(\d+|\.\d+|\d+\.\d+)$") {$v = "-"}
                            }
                            $SMIresultSplit[$i] = $v                        
                        }
                        $Devices | Where-Object Type_Vendor_Index -eq $DeviceId | Foreach-Object {
                            $Data = [PSCustomObject]@{
                                Utilization       = if ($SMIresultSplit[1] -eq "-") {100} else {[int]$SMIresultSplit[1]} #If we dont have real Utilization, at least make the watchdog happy
                                UtilizationMem    = if ($SMIresultSplit[2] -eq "-") {$null} else {[int]$SMIresultSplit[2]}
                                Temperature       = if ($SMIresultSplit[3] -eq "-") {$null} else {[int]$SMIresultSplit[3]}
                                PowerDraw         = if ($SMIresultSplit[4] -eq "-") {$null} else {[int]$SMIresultSplit[4]}
                                PowerLimit        = if ($SMIresultSplit[5] -eq "-") {$null} else {[int]$SMIresultSplit[5]}
                                FanSpeed          = if ($SMIresultSplit[6] -eq "-") {$null} else {[int]$SMIresultSplit[6]}
                                Pstate            = $SMIresultSplit[7]
                                Clock             = if ($SMIresultSplit[8] -eq "-") {$null} else {[int]$SMIresultSplit[8]}
                                ClockMem          = if ($SMIresultSplit[9] -eq "-") {$null} else {[int]$SMIresultSplit[9]}
                                PowerMaxLimit     = if ($SMIresultSplit[10] -eq "-") {$null} else {[int]$SMIresultSplit[10]}
                                PowerDefaultLimit = if ($SMIresultSplit[11] -eq "-") {$null} else {[int]$SMIresultSplit[11]}
                                Method            = "smi"
                            }
                            if ($Data.PowerDefaultLimit -gt 0) {$Data | Add-Member PowerLimitPercent ([math]::Floor(($Data.PowerLimit * 100) / $Data.PowerDefaultLimit))}
                            if (-not $Data.PowerDraw -and $Script:NvidiaCardsTDP."$($_.Model_Name)") {$Data.PowerDraw = $Script:NvidiaCardsTDP."$($_.Model_Name)" * ([double]$Data.PowerLimitPercent / 100) * ([double]$Data.Utilization / 100)}
                            $_ | Add-Member Data $Data -Force
                        }
                        $DeviceId++
                    }
                }
            }
        } catch {
            if ($Error.Count){$Error.RemoveAt(0)}
            Write-Host "Could not read power data from NVIDIA: : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    try { #CPU
        if (-not $DeviceName -or $DeviceName -like "CPU*") {
            $CPU_count = $Global:GlobalCachedDevices.Features.physical_cpus | Select-Object -First 1
            $CPUcore_count = ($Global:GlobalCachedDevices | Where-Object Type -eq "Cpu" | Measure-Object).Count
            $CPUPowerDraw = 0
            if ($UseAfterburner -and $Script:abMonitor -and $CPU_count -eq 1) {
                if ($abReload) {$Script:abMonitor.ReloadAll()}
                $abReload = $false
                $CPUPowerDraw = [int]$($Script:abMonitor.Entries | Where-Object SrcName -eq 'CPU power').Data
                $CPUmethod = "ab"
            }

            try {
                $CPULoadCores = (Get-CimInstance -Query "select Name, PercentProcessorTime from Win32_PerfFormattedData_PerfOS_Processor") | Where-Object Name -ne "_Total" | Select-Object -Property Name,PercentProcessorTime
                $CPULoadCalc  = ($CPULoadCores | Select-Object -ExpandProperty PercentProcessorTime | Measure-Object -Average -Sum) | Select-Object -Property Average,Sum
            } catch {
                if ($Error.Count){$Error.RemoveAt(0)}
                Write-Host "Could not read Get-CimInstance: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            if (-not $CPULoadCalc.Average) {
                $Global:GlobalGetDeviceCacheCIM = Get-CimInstance -ClassName CIM_Processor
                $CPULoadCalc = ($Global:GlobalGetDeviceCacheCIM.LoadPercentage | Measure-Object -Average -Sum) | Select-Object -Property Average,Sum
                if (-not $CPULoadCalc.Average) {$CPULoadCalc.Average = 100;$CPULoadCalc.Sum = 100}
                $CPULoadCalc.Sum *= $CPUcore_count
            }

            if (-not $CPUPowerDraw) {
                if (-not (Test-Path Variable:Script:CpuTDP)) {$Script:CpuTDP = Get-Content ".\Data\cpu-tdp.json" -Raw | ConvertFrom-Json}
                if (-not ($CPUPowerDraw = $Script:CpuTDP.(($Global:GlobalCachedDevices.CIM.Name | Select-Object -First 1).Trim()))) {$CPUPowerDraw = ($Script:CpuTDP.PSObject.Properties.Value | Measure-Object -Average).Average}
                if ($CPULoadCalc) {$CPUPowerDraw *= $CPULoadCalc.Average/100}
                $CPUmethod = "tdp"
            }

            $Global:GlobalCachedDevices | Where-Object {$_.Type -eq "CPU"} | Foreach-Object {
                $CPUCoreFrac = $(if ($CPULoadCores) {$CPULoadCores | Where-Object Name -eq $($_.CPU_Thread) | Select-Object -ExpandProperty PercentProcessorTime} else {@($Global:GlobalGetDeviceCacheCIM)[$_.Type_PlatformId_Index].LoadPercentage})
                $_ | Add-Member Data ([PSCustomObject]@{
                    Cores         = [int]$_.CPU_Features.Cores
                    Threads       = [int]$_.CPU_Features.Threads
                    CacheL3       = [int]$_.CIM.L3CacheSize
                    Clock         = [int]$_.CIM.MaxClockSpeed
                    Utilization   = [int]$CPUCoreFrac
                    PowerDraw     = [int]($CPUPowerDraw*$CPUCoreFrac/$CPULoadCalc.Sum)
                    PowerDraw_Total = [int]$CPUPowerDraw
                    Temperature   = [int]0
                    Method        = $CPUmethod
                }) -Force
            }
        }
    } catch {
        if ($Error.Count){$Error.RemoveAt(0)}
        Write-Host "Could not read power data from CPU: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Start-Afterburner

Update-DeviceInformationDebug @(Get-DeviceDebug @("cpu","gpu") | Select-Object -ExpandProperty Name -Unique)

@(Get-DeviceDebug @("cpu") | Format-Table -Wrap -Property Name,
                                @{Name="Thread";   Expression={$_.CPU_Thread};                               Alignment="Center"},
                                @{Name="Clock";    Expression={"$([math]::round($_.Data.Clock/1000,3))GHz"}; Alignment="Center"},
                                @{Name="CacheL3";  Expression={"$([math]::round($_.Data.CacheL3/1024,3))GB"}; Alignment="Center"},
                                @{Name="Method";   Expression={$_.Data.Method};                  Alignment="Center"},
                                @{Name="Load";     Expression={"$($_.Data.Utilization)%"};                   Alignment="Center"},
                                @{Name="Power";    Expression={"$($_.Data.PowerDraw)W"};                     Alignment="Center"},
                                @{Name="Cores";    Expression={$_.Data.Cores};                    Alignment="Center"},
                                @{Name="Threads";  Expression={$_.Data.Threads};                  Alignment="Center"},
                                @{Name="PowerTotal";    Expression={"$($_.Data.PowerDraw_Total)W"};          Alignment="Center"},
                                @{Name="Features";    Expression={($_.CPU_Features.GetEnumerator() | Where-Object {$_.Name -notmatch '_' -and $_.Value -eq 1} | Select-Object -ExpandProperty Name | Sort-Object) -join ','}; Alignment="Left"},
                                @{Name="CPU Name"; Expression={$_.Model_Name}})

@(Get-DeviceDebug @("gpu") | Format-Table -Property Name,Vendor,Model,
                                @{Name="Driver";    Expression={$_.OpenCL.DriverVersion};                                                                                  Alignment="Right"},
                                @{Name="CL/CUDA";   Expression={if ($_.OpenCL.Platform.Version -match "CUDA") {$_.OpenCL.Platform.Version -replace "^.*CUDA\s+"}else{$_.OpenCL.Platform.Version -replace "^.*OpenCL\s+"}}; Alignment="Right"},
                                @{Name="Mem";       Expression={$(if ($_.OpenCL.GlobalMemSize -ne $null) {"$([math]::round($_.OpenCL.GlobalMemSize/1gb,3))GB"}else{"-"})}; Alignment="Right"},
                                @{Name="PS";        Expression={$(if ($_.Data.Pstate -ne $null) {$_.Data.Pstate}else{"-"})};                                               Alignment="Right"},
                                @{Name="Gpu Clock"; Expression={$(if ($_.Data.Clock -ne $null) {"$([math]::round($_.Data.Clock/1000,3))GHz"}else{"-"})};                   Alignment="Right"},
                                @{Name="Mem Clock"; Expression={$(if ($_.Data.ClockMem -ne $null) {"$([math]::round($_.Data.ClockMem/1000,3))GHz"}else{"-"})};             Alignment="Right"},
                                @{Name="Temp";      Expression={$(if ($_.Data.Temperature -ne $null) {"$($_.Data.Temperature)°C"}else{"-"})};                              Alignment="Right"},
                                @{Name="Fan%";      Expression={$(if ($_.Data.FanSpeed -ne $null) {"$($_.Data.FanSpeed)%"}else{"-"})};                                     Alignment="Right"},
                                @{Name="Gpu%";      Expression={$(if ($_.Data.Utilization -ne $null) {"$($_.Data.Utilization)%"}else{"-"})};                               Alignment="Right"},
                                @{Name="Mem%";      Expression={$(if ($_.Data.UtilizationMem -ne $null) {"$($_.Data.UtilizationMem)%"}else{"-"})};                         Alignment="Right"},
                                @{Name="PLim%";     Expression={$(if ($_.Data.PowerLimitPercent -ne $null) {"$($_.Data.PowerLimitPercent)%"}else{"-"})};                   Alignment="Right"},
                                @{Name="Power";     Expression={$(if ($_.Data.PowerLimitPercent -ne $null) {"$($_.Data.PowerDraw)W"}else{"-"})};                           Alignment="Right"})
