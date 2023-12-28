﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$ManualUri = "https://github.com/develsoftware/GMinerRelease/releases"
$Port = "329{0:d2}"
$DevFee = 2.0
$Cuda = "9.0"
$Version = "3.43"
$DeviceCapability = "5.0"
$EnableContest = $false

if ($IsLinux) {
    $Path = ".\Bin\GPU-Gminer\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.43-gminer/gminer_3_43_linux64.tar.xz"
} else {
    $Path = ".\Bin\GPU-Gminer\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.43-gminer/gminer_3_43_windows64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 3;                     Params = "--algo autolykos2";  Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 2.0} #Autolykos2/ERG
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                    MinMemGb = 1;                     Params = "--algo beamhash";    Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true} #BeamHash3
    [PSCustomObject]@{MainAlgorithm = "Cortex";                       MinMemGb = 8;                     Params = "--algo cortex";      Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; NoCPUMining = $false; Fee = 5.0} #Cortex
    [PSCustomObject]@{MainAlgorithm = "CuckooCycle";                  MinMemGb = 3;                     Params = "--algo aeternity";   Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 2.0; NoCPUMining = $false} #Cortex
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";                 MinMemGb = 2;                     Params = "--algo 144_5";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; AutoPers = $true} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";                MinMemGb = 2;                     Params = "--algo 125_4";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; AutoPers = $true} #Equihash 125,4/ZelHash
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";                 MinMemGb = 0.5;                   Params = "--algo 210_9";       Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; AutoPers = $true} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Etchash
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGb = 3;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGb = 1;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGb = 2;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGb = 3;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGb = 4;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGb = 2;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "FiroPoW";         DAG = $true; MinMemGb = 3;                     Params = "--algo firo";        Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #FiroPOW
    [PSCustomObject]@{MainAlgorithm = "Blake3IronFish";               MinMemGb = 1;                     Params = "--algo ironfish";    Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #Blake3IronFish/IRON
    [PSCustomObject]@{MainAlgorithm = "KarlsenHash";                  MinMemGb = 1;                     Params = "--algo karlsenhash"; Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 1.00; ZilFee=2.00} #KarlsenHash/KLS
    [PSCustomObject]@{MainAlgorithm = "KawPOW";          DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW2g";        DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW3g";        DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW4g";        DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "KawPOW5g";        DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kHeavyHash";                   MinMemGb = 1;                     Params = "--algo kheavyhash";  Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 1.00; ExcludePoolName = "MiningRigRentals"} #kHeavyHash/KAS
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; MinMemGb = 6;                     Params = "--algo octopus";     Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 4.00} #Octopus/CFX
    [PSCustomObject]@{MainAlgorithm = "ProgpowSero";     DAG = $true; MinMemGb = 3;                     Params = "--algo sero";        Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 1.00} #ProgpowSero
    [PSCustomObject]@{MainAlgorithm = "SHA256ton";                    MinMemGb = 1;                     Params = "--algo ton";         Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 2.00} #SHA256ton/TON
    [PSCustomObject]@{MainAlgorithm = "SHA512256d";                   MinMemGb = 1;                     Params = "--algo radiant";     Vendor = @("NVIDIA");       ExtendInterval = 2; DualZIL = $true; Fee = 2.00} #SHA512256d/RAD


    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 3;                     Params = "--algo autolykos2 --dalgo ironfish"; Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 2.0; SecondaryAlgorithm = "Blake3IronFish"} #Autolykos2/ERG+IRON
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 3;                     Params = "--algo autolykos2 --dalgo kaspa";    Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 2.0; SecondaryAlgorithm = "kHeavyHash"} #Autolykos2/ERG+KAS
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";      DAG = $true; MinMemGb = 3;                     Params = "--algo autolykos2 --dalgo radiant";  Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 2.0; SecondaryAlgorithm = "SHA512256d"} #Autolykos2/ERG+RAD
    [PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash --dalgo ironfish";    Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "Blake3IronFish"} #Etchash+IRON
    [PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash --dalgo kaspa";       Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Etchash+KAS
    [PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash --dalgo radiant";     Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "SHA512256d"} #Etchash+RAD
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGb = 3;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; MinMemGb = 1;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; MinMemGb = 2;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; MinMemGb = 3;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; MinMemGb = 4;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGb = 2;                     Params = "--algo ethash --dalgo kaspa";        Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 1.00; SecondaryAlgorithm = "kHeavyHash"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; MinMemGb = 6;                     Params = "--algo octopus --dalgo ironfish";    Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 4.00; SecondaryAlgorithm = "Blake3IronFish"} #Octopus+IRON
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; MinMemGb = 6;                     Params = "--algo octopus --dalgo kaspa";       Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 4.00; SecondaryAlgorithm = "kHeavyHash"} #Octopus+KAS
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; MinMemGb = 6;                     Params = "--algo octopus --dalgo radiant";     Vendor = @("NVIDIA"); ExtendInterval = 2; DualZIL = $true; Fee = 4.00; SecondaryAlgorithm = "SHA512256d"} #Octopus+RAD

    #[PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash --dalgo ton";    Vendor = @("NVIDIA");       ExtendInterval = 3; DualZIL = $true; Fee = 1.50; SecondaryAlgorithm = "SHA256ton"} #Etchash + SHA256ton
    #[PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGb = 3;                     Params = "--algo ethash --dalgo ton";     Vendor = @("NVIDIA");       ExtendInterval = 3; DualZIL = $true; Fee = 1.50; SecondaryAlgorithm = "SHA256ton"} #Ethash + SHA256ton
    #[PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGb = 2;                     Params = "--algo ethash --dalgo ton";     Vendor = @("NVIDIA");       ExtendInterval = 3; DualZIL = $true; Fee = 1.50; SecondaryAlgorithm = "SHA256ton"} #Ethash for low memory coins + SHA256ton
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

$ContestWallet = if ($EnableContest) {if ($Session.Config.Coins.ETH.Wallet -match "^0x[0-9a-f]{40}$") {$Session.Config.Coins.ETH.Wallet} else {"0xaaD1d2972f99A99248464cdb075B28697d4d8EEd"}}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model -and ($Miner_Vendor -ne "NVIDIA" -or -not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)})

        if (-not $Device) {return}

        $VendorParams = if ($Miner_Vendor -eq "NVIDIA") {" --nvml 1"} elseif ($Miner_Vendor -eq "AMD") {" --nvml 0"}

        $ZilParams = ""

        if ($Session.Config.Pools.CrazyPool.EnableGminerDual -and $Pools.ZilliqaCP) {
            if ($ZilWallet = $Pools.ZilliqaCP.Wallet) {
                $ZilParams = " --zilserver $($Pools.ZilliqaCP.Protocol)://$($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port) --ziluser $($Pools.ZilliqaCP.User)"
            }
        }

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)}).ForEach({
            $First = $true
            
            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})

		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.BusId_Type_Vendor_Index -join ' '
                        $First = $false
                    }

                    $PersCoin = if ($MainAlgorithm_Norm -match "^Equihash") {Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"}
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    if ($SecondAlgorithm_Norm_0) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = 0}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -gt 0) {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                $DeviceIntensitiesAll = " $($Intensity)"*($Miner_Device | Measure-Object).Count
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $DeviceIntensitiesAll = $null
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}

				                    [PSCustomObject]@{
					                    Name           = $Miner_Name_Dual
					                    DeviceName     = $Miner_Device.Name
					                    DeviceModel    = $Miner_Model
					                    Path           = $Path
					                    Arguments      = "--api `$mport --devices $($DeviceIDsAll)$(if ($DeviceIntensitiesAll) {" --dual_intensity$($DeviceIntensitiesAll)"}) --server $($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"})$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1 --ssl_verification 0"} else {" --ssl 0"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --dserver $(if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.Protocol) {"$($Pools.$SecondAlgorithm_Norm.Protocol)://"})$($Pools.$SecondAlgorithm_Norm.Host)$(if ($SecondPool_Port -and $Pools.$SecondAlgorithm_Norm.Host -notmatch "/") {":$($SecondPool_Port)"}) --duser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker) {" --dworker $($Pools.$SecondAlgorithm_Norm.Worker)"})$(if ($SecondAlgorithm_Norm_0 -ne "SHA256ton") {if ($Pools.$SecondAlgorithm_Norm.SSL) {" --dssl 1"} else {" --dssl 0"}})$(if ($ContestWallet) {" --contest_wallet $($ContestWallet)"})$($ZilParams) --watchdog 0 --pec 0$($VendorParams) $($_.Params)"
					                    HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                            $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                        }
					                    API            = "Gminer"
					                    Port           = $Miner_Port
                                        FaultTolerance = $_.FaultTolerance
					                    ExtendInterval = $_.ExtendInterval
                                        Penalty        = 0
					                    DevFee         = [PSCustomObject]@{
								                            ($MainAlgorithm_Norm) = if ($_.ZilFee -ne $null -and $ZilParams -ne "") {$_.ZilFee} elseif ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
								                            ($SecondAlgorithm_Norm) = 0
                                                          }
					                    Uri            = $Uri
					                    ManualUri      = $ManualUri
					                    NoCPUMining    = $_.NoCPUMining
                                        Version        = $Version
                                        PowerDraw      = 0
                                        BaseName       = $Name
                                        BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        ExcludePoolName= $_.ExcludePoolName
                                        DualZIL        = $ZilParams -ne ""
				                    }
                                }
                            }
                        }
                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll) --server $(if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.Protocol) {"$($Pools.$MainAlgorithm_Norm.Protocol)://"})$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"})$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($MainAlgorithm_Norm_0 -ne "SHA256ton") {if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1 --ssl_verification 0"} else {" --ssl 0"}}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD"))$(if ($ContestWallet) {" --contest_wallet $($ContestWallet)"})$($ZilParams) --watchdog 0 --pec 0$($VendorParams) $($_.Params)"
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
					        API            = "Gminer"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = if ($_.ZilFee -ne $null -and $ZilParams -ne "") {$_.ZilFee} elseif ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
					        Uri            = $Uri
					        ManualUri      = $ManualUri
					        NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            ExcludePoolName= $_.ExcludePoolName
                            DualZIL        = $ZilParams -ne ""
				        }
                    }
			    }
		    }
        })
    }
}