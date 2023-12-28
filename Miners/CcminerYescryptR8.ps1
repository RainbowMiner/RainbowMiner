﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-YesCryptR8\ccminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21r17kotov2-ccminerklaust/ccminer-KlausT-8.21-mod-r17-koto-sapling-2.7z"
            Cuda = "9.1"
        }
    )
    $ManualUri = "https://github.com/Kudaraidee/ccminer-KlausT-8.21-mod-koto-sapling-2/releases"
    $Version = "8.21-r17kotov2"
} else {
    $Path = ".\Bin\NVIDIA-YesCryptR8\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21r18v5-ccminerklaust/ccmineryescryptrV5.7z"
            Cuda = "10.1"
        }
    )
    $ManualUri = "https://github.com/Minerx117/ccmineryescryptr8g/releases"
    $Version = "8.21-r18v5"
}

$Port = "137{0:d2}"
$DevFee = 0.0

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = "-a yescryptr16"; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = "-a yescryptr32"; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptR8"; Params = "-a yescryptR8"; ExtendInterval = 2; FaultTolerance = 0.3} #YesctyptR8
    [PSCustomObject]@{MainAlgorithm = "yescryptR8G"; Params = "-a yescrypt"; ExtendInterval = 2; FaultTolerance = 0.3} #YesctyptR8G
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
    }
}

if (-not $Cuda) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if (-not $Pools.$Algorithm_Norm.SSL -and $Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--no-cpu-verify -N 1 -R 1 -b `$mport -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Day * $(if ($_.Penalty -ne $null) {$_.Penalty} else {1})}
					API            = "Ccminer"
					Port           = $Miner_Port
					URI            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
                    DevFee         = $DevFee
					ManualUri      = $ManualUri
					MiningPriority = 2
					MaxRejectedShareRatio = if ($_.MaxRejectedShareRatio) {$_.MaxRejectedShareRatio} else {0.5}
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				}
			}
		}
    })
}