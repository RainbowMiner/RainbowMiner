﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.71-cast/cast_xmr-vega-ubuntu_171.tar.gz"
    $Version = "1.7.1"
} else {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.8.0-cast/cast_xmr-vega-win64_180.zip"
    $Version = "1.8.0"
}
$Port = "306{0:d2}"
$DevFee = 1.0

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(    
    [PSCustomObject]@{MainAlgorithm = "cryptonightfast"; Params = "--algo=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightheavy"; Params = "--algo=2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightlite"; Params = "--algo=3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightsuperfast"; Params = "--algo=11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonighttubeheavy"; Params = "--algo=5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightturtle"; Params = "--algo=9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = "--algo=1"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7lite"; Params = "--algo=4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8fast"; Params = "--algo=6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8"; Params = "--algo=10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightxhvheavy"; Params = "--algo=7"}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Devices = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params

        $Miner_Device = $Devices | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb) -and $_.OpenCL.Name -match "^(Ellesmere|Polaris|Vega|gfx900)"}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
		            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
		            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = ($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--remoteaccess --remoteport `$mport -S $($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --opencl $($Miner_Device | Select-Object -First 1 -ExpandProperty PlatformId) -G $($DeviceIDsAll) --fastjobswitch --intensity -1$(if ($Pools.$Algorithm_Norm.Name -notmatch "NiceHash") {" --nonicehash"}) $($_.Params)" 
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Cast"
					Port           = $Miner_Port
					URI            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    })
}