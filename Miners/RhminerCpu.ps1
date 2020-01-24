﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-RHminer\rhminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.1-rhminer/rhminer.2.1.Linux.CPU.zip"
} else {
    $Path = ".\Bin\CPU-RHminer\rhminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.1-rhminer/rhminer.2.1.Windows.CPU.zip"
}
$ManualUri = "https://github.com/polyminer1/rhminer/releases"
$Port = "131{0:d2}"
$DevFee = 1.0
$Version = "2.1"

if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "randomhash2"; Params = ""; ExtendInterval = 2} #RandomHash/PASCcoin
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model
    
    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){" -cputhreads $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" -processorsaffinity $((ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity) -join ",")"})"
                    $First = $false
                }
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-apiport `$mport -s $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -su $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -pw $($Pools.$Algorithm_Norm.Pass)"}) -cpu$($DeviceParams) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Claymore"
                    #API            = "RHWrapper" just in case the claymore API is broken
					Port           = $Miner_Port
					Uri            = $Uri
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
    }
}
