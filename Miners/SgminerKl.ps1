﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\AMD-SgminerKl\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.9-sgminerkl/sgminer-kl-1.0.9-windows.zip"
$ManualUri = "https://github.com/KL0nLutiy/sgminer-kl/releases"
$Port = "402{0:d2}"
$DevFee = 1.0
$Version = "1.0.9"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-X 256 -g 2"} #Aergo
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = "-X 256 -g 2"} #C11
    [PSCustomObject]@{MainAlgorithm = "geek"; Params = "-X 256 -g 2"} #Geek
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = "-X 256 -g 2 -w 256"} # Phi
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = "-X 256 -g 2 -w 256"} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-X 256 -g 2 -w 256"} # Skunk
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-X 256 -g 2"} #Tribus
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-X 256 -g 2"} #Xevan
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-X 256 -g 2"} #X16S Pigeoncoin
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-X 256 -g 2"} #X16R Ravencoin
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "-X 256 -g 2"} #X17
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
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'    
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $Miner_PlatformId = $Miner_Device | Select -Unique -ExpandProperty PlatformId
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--device $($DeviceIDsAll) --api-port `$mport --api-listen -k $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Xgminer"
					Port           = $Miner_Port
					URI            = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
					EnvVars        = @("GPU_FORCE_64BIT_PTR=0")
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    })
}