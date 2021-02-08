﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\Equihash-EWBF\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-ewbf/EWBF_Equihash_miner_v0.6.tar.gz"
} else {
    $Path = ".\Bin\Equihash-EWBF\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-ewbf/EWBF.Equihash.miner.v0.6.zip"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"
$DevFee = 0.0
$Cuda = "8.0"
$Version = "0.6"

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash965";  MinMemGB = 2.5; Params = "--algo 96_5"; ExcludePoolName = "^Nicehash"}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1445"; MinMemGB = 2; Params = "--algo 144_5"; ExcludePoolName = "^Nicehash"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1927"; MinMemGB = 2.5; Params = "--algo 192_7"; ExcludePoolName = "^Nicehash"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash2109"; MinMemGB = 0.5; Params = "--algo 210_9"; ExcludePoolName = "^Nicehash"} #Equihash 210,9 (beta)
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
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

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB        
        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
        
		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName) -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api 127.0.0.1:`$mport --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($Algorithm_Norm -match "^Equihash") {" --pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto")"}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					API            = "DSTM"
					Port           = $Miner_Port
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = 2
                    Penalty        = 0
					DevFee         = $DevFee
					Uri            = $Uri
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