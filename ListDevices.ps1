using module .\Include.psm1

if ($MyInvocation.MyCommand.Path) {Set-Location (Split-Path $MyInvocation.MyCommand.Path)}

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
                }

                if (-not $Type_PlatformId_Index."$($Device_OpenCL.Type)") {
                    $Type_PlatformId_Index."$($Device_OpenCL.Type)" = @{}
                }
                if (-not $Type_Vendor_Index."$($Device_OpenCL.Type)") {
                    $Type_Vendor_Index."$($Device_OpenCL.Type)" = @{}
                }

                $Index++
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
        $Error.Remove($Error[$Error.Count - 1])
        Write-Host "OpenCL device detection has failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        $CPUIndex = 0
        if (-not (Test-Path Variable:Global:GlobalGetDeviceCacheCIM)) {
            $Global:GlobalGetDeviceCacheCIM = Get-CimInstance -ClassName CIM_Processor
        }
        $Global:GlobalGetDeviceCacheCIM | Foreach-Object {
            # Vendor and type the same for all CPUs, so there is no need to actually track the extra indexes.  Include them only for compatibility.
            $CPUInfo = $_ | ConvertTo-Json | ConvertFrom-Json
            $Device = [PSCustomObject]@{
                Index = [Int]$Index
                Vendor = if ($GPUVendorLists.INTEL -icontains $CPUInfo.Manufacturer){"INTEL"}else{$CPUInfo.Manufacturer}
                Vendor_Name = $CPUInfo.Manufacturer
                Type_PlatformId_Index = $CPUIndex
                Type_Vendor_Index = $CPUIndex
                Type = "Cpu"
                Type_Index = $CPUIndex
                Type_Mineable_Index = $CPUIndex
                CIM = $CPUInfo
                Model = "CPU"
                Model_Name = $CPUInfo.Name
            }

            if ((-not $Name) -or ($Name_Devices | Where-Object {($Device | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name)) -like ($_ | Select-Object ($_ | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name))})) {
                $Devices += $Device | Add-Member Name ("{0}#{1:d2}" -f $Device.Type, $Device.Type_Index).ToUpper() -PassThru
            }

            $CPUIndex++
            $Index++
        }
    }
    catch {
        $Error.Remove($Error[$Error.Count - 1])
        Write-Host "CIM CPU detection has failed. " -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    $Global:GlobalCachedDevices = $Devices
    $Devices
}

Start-Afterburner

Update-DeviceInformation @(Get-DeviceDebug @("cpu","gpu") | Select-Object -ExpandProperty Name -Unique)

@(Get-DeviceDebug @("cpu") | Format-Table -Property Name,
                                @{Name="Cores";    Expression={$_.Data.Cores};                               Alignment="Center"},
                                @{Name="Threads";  Expression={$_.Data.Threads};                             Alignment="Center"},
                                @{Name="Clock";    Expression={"$([math]::round($_.Data.Clock/1000,3))GHz"}; Alignment="Center"},
                                @{Name="Load";     Expression={"$($_.Data.Utilization)%"};                   Alignment="Center"},
                                @{Name="Power";    Expression={"$($_.Data.PowerDraw)W"};                     Alignment="Center"},
                                @{Name="CPU Name"; Expression={$_.Model_Name}})

@(Get-DeviceDebug @("gpu") | Format-Table -Property Name,Vendor,Model,
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

