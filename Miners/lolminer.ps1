﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\Equihash-lolMiner\lolMiner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.6-lolminer/lolMiner_v096_Lin64.tar.gz"
} else {
    $Path = ".\Bin\Equihash-lolMiner\lolMiner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.6-lolminer/lolMiner_v096_Win64.zip"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "317{0:d2}"
$Cuda = "10.0"
$DevFee = 1.0
$Version = "0.9.6"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";     MinMemGB = 4; MinMemGBWin10 = 6; Params = "--coin GRIN-C29D"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $true} #Cuckarood29
    [PSCustomObject]@{MainAlgorithm = "Cuckaroom29";     MinMemGB = 4; MinMemGBWin10 = 6; Params = "--coin GRIN-C29M"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $true} #Cuckaroom29
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";      MinMemGB = 8; MinMemGBWin10 = 10; Params = "--coin GRIN-C31"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $true} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";      MinMemGB = 8; MinMemGBWin10 = 10; Params = "--coin GRIN-C32"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $true} #Cuckatoo32
    [PSCustomObject]@{MainAlgorithm = "Equihash16x5";    MinMemGB = 2; MinMemGBWin10 = 2; Params = "--coin MNX";       Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $false} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";    MinMemGB = 1; MinMemGBWin10 = 2; Params = "--coin AION";      Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $false} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";    MinMemGB = 2; MinMemGBWin10 = 3; Params = "--coin AUTO144_5"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $false} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";    MinMemGB = 3; MinMemGBWin10 = 4; Params = "--coin AUTO192_7"; Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $false} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";   MinMemGB = 3; MinMemGBWin10 = 4; Params = "--coin ZEL";       Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $false} #Equihash 125,4,0
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3"; MinMemGB = 3; MinMemGBWin10 = 4; Params = "--coin BEAM";      Fee=1; ExtendInterval = 2; Vendor = @("AMD"); NH = $true} #Equihash 150,5,3
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

#if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

			foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "NiceHash")) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }
                    $PersCoin   = if (@("Equihash16x5","Equihash24x5","Equihash24x7") -icontains $Algorithm_Norm) {Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto"}
					$Pool_Port  = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                
					[PSCustomObject]@{
						Name           = $Miner_Name
						DeviceName     = $Miner_Device.Name
						DeviceModel    = $Miner_Model
						Path           = $Path
						Arguments      = "--pool $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"}) --devices $($Miner_Device.Type_Vendor_Index -join ',') --apiport `$mport --tls $(if ($Pools.$Algorithm_Norm.SSL) {1} else {0}) --digits 2 --longstats 60 --shortstats 5 --connectattempts 3$(if ($PersCoin -and $PersCoin -ne "auto") {" --overwritePersonal $PersCoin"}) $($_.Params)"
						HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
						API            = "Lol"
						Port           = $Miner_Port
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
						DevFee         = $_.Fee
						Uri            = $Uri
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
}
