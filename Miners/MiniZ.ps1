﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=4767892.0"
$Port = "330{0:d2}"
$DevFee = 2.0
$Version = "1.7x4"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-MiniZ\miniZ"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.7x4-miniz/miniZ_v1.7x4_linux-x64.tar.gz"
            Cuda = "8.0"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-MiniZ\miniZ.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.7x4-miniz/miniZ_v1.7x4_win-x64.7z"
            Cuda = "8.0"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                  MinMemGB = 5; Params = "--par=beam3";    ExtendInterval = 3; AutoPers = $false; Fee = $DevFee} #BeamHash3 (BEAM)
    #[PSCustomObject]@{MainAlgorithm = "EtcHash";       DAG = $true; MinMemGB = 2; Params = "--par=etchash";  ExtendInterval = 3; AutoPers = $false; Fee = 0.75} #Etchash (ETC)
    [PSCustomObject]@{MainAlgorithm = "Ethash";        DAG = $true; MinMemGB = 2; Params = "--par=ethash";   ExtendInterval = 3; AutoPers = $false; Fee = 0.75} #Ethash (ETH)
    [PSCustomObject]@{MainAlgorithm = "Equihash16x5";               MinMemGB = 1; Params = "--par=96,5";     ExtendInterval = 2; AutoPers = $true;  Fee = $DevFee} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";               MinMemGB = 2; Params = "--par=144,5";    ExtendInterval = 2; AutoPers = $true;  Fee = $DevFee} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";               MinMemGB = 2; Params = "--par=192,7";    ExtendInterval = 2; AutoPers = $true;  Fee = $DevFee} #Equihash 192,7 
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";              MinMemGB = 2; Params = "--par=125,4";    ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee} #Equihash 125,4,0 (ZelCash)
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5";              MinMemGB = 3; Params = "--par=150,5";    ExtendInterval = 3; AutoPers = $true;  Fee = $DevFee} #Equihash 150,5,0 (GRIMM)
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";               MinMemGB = 2; Params = "--par=210,9";    ExtendInterval = 2; AutoPers = $true;  Fee = $DevFee} #Equihash 210,9 (AION)
    [PSCustomObject]@{MainAlgorithm = "KawPoW";        DAG = $true; MinMemGB = 2; Params = "--par=kawpow";   ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #KawPow (RVN)
    [PSCustomObject]@{MainAlgorithm = "ProgPowSero";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow";  ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #ProgPowSero (SERO)
    [PSCustomObject]@{MainAlgorithm = "ProgPowVeil";   DAG = $true; MinMemGB = 2; Params = "--par=ProgPow";  ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #ProgPowVeil (VEIL)
    [PSCustomObject]@{MainAlgorithm = "ProgPowZ";      DAG = $true; MinMemGB = 2; Params = "--par=ProgPowZ"; ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #ProgPowZano (ZANO)
    [PSCustomObject]@{MainAlgorithm = "vProgPow";      DAG = $true; MinMemGB = 2; Params = "--par=vProgPow"; ExtendInterval = 3; AutoPers = $false; Fee = 1.00} #vProgPow (VBK)
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
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
                    $First = $false
                }
                $PersCoin = Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto"
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--telemetry=`$mport -cd $($DeviceIDsAll) --url=$(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})$(Get-UrlEncode $Pools.$Algorithm_Norm.User)@$($Pools.$Algorithm_Norm.Host):$($Pool_Port)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass=$($Pools.$Algorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers=$($PersCoin)"}) --gpu-line --extra --latency$(if (-not $Session.Config.ShowMinerWindow) {" --nocolor"})$(if ($Pools.$Algorithm_Norm.Name -eq "MiningRigRentals" -and $PersCoin -ne "auto") {" --smart-pers"}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					API            = "MiniZ"
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
    })
}