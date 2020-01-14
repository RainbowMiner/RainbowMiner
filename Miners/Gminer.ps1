using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-Gminer\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.93-gminer/gminer_1_93_linux64.tar.xz"
} else {
    $Path = ".\Bin\GPU-Gminer\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.93-gminer/gminer_1_93_windows64.zip"
}
$ManualUri = "https://github.com/develsoftware/GMinerRelease/releases"
$Port = "329{0:d2}"
$DevFee = 2.0
$Cuda = "9.0"
$Version = "1.93"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Aeternity";       MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo aeternity";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true} #Cuckoo29/Aeternity
    [PSCustomObject]@{MainAlgorithm = "Blake2s";         MinMemGb = 2;                     Params = "--algo blake2s";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $false; NoCPUMining = $false; Coins = @("KDA")} #Blake2s
    [PSCustomObject]@{MainAlgorithm = "Cortex";          MinMemGb = 8;   MinMemGbW10 = 10; Params = "--algo cortex";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; NoCPUMining = $false; Fee = 5.0} #Cortex
    [PSCustomObject]@{MainAlgorithm = "CryptoNightBBC";  MinMemGb = 2;   MinMemGbW10 = 4;  Params = "--algo bbc";         Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; NoCPUMining = $true;  Fee = 5.0} #CryptonightBBC
    [PSCustomObject]@{MainAlgorithm = "CuckooBFC";       MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo bfc";         Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true;  Fee = 3.0} #Equihash Cuckoo29/BFC
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29";      MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo cuckaroo29";  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true} #Cuckaroo29/BitGRIN
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";     MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo swap";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true} #Cuckaroo29s/SWAP
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";      MinMemGb = 8;   MinMemGbW10 = 10; Params = "--algo grin31";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; NoCPUMining = $true} #Cuckatoo31/GRIN31
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";     MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo cuckarood29"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true} #Cuckarood29/GRIN upto 01/16/2020
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29v";    MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo cuckarood29v";Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true; Fee = 10.0} #Cuckarood29v/MoneroV
    [PSCustomObject]@{MainAlgorithm = "Cuckaroom29";     MinMemGb = 4;   MinMemGbW10 = 6;  Params = "--algo cuckaroom29"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; NoCPUMining = $true; Fee = 3.0} #Cuckaroom29/GRIN from 01/16/2020
    [PSCustomObject]@{MainAlgorithm = "Eaglesong";       MinMemGb = 2;                     Params = "--algo eaglesong";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; AutoPers = $false} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash16x5";    MinMemGb = 2;                     Params = "--algo 96_5";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; AutoPers = $false} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";    MinMemGb = 2;                     Params = "--algo 144_5";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; AutoPers = $true} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";   MinMemGb = 2;                     Params = "--algo 125_4";       Vendor = @("AMD","NVIDIA");       ExtendInterval = 2; NH = $true; AutoPers = $true} #Equihash 125,4/ZelHash
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5";   MinMemGb = 3;                     Params = "--algo 150_5";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; AutoPers = $false} #Equihash 150,5,0 (GRIMM)
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3"; MinMemGb = 3;                     Params = "--algo BeamHashII";  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; AutoPers = $false} #Equihash 150,5,3 (BEAM)
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";    MinMemGb = 3.0;                   Params = "--algo 192_7";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NH = $true; AutoPers = $true} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";    MinMemGb = 0.5;                   Params = "--algo 210_9";       Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; AutoPers = $true} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "EquihashVds";     MinMemGb = 2;                     Params = "--algo vds";         Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; AutoPers = $false} #Equihash 96,5 + Scrypt "VDS"
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;                     Params = "--algo ethash";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 0.65} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 0;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 1;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 2;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 3;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 4;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 5;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 6;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 7;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 8;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 9;    Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 10;   Params = "--algo ethash+blake2s";        Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Blake2s"; NH2 = $false; Coins2 = @("KDA")} #Ethash+Blake2s
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 0;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 1;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 2;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 3;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 4;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 5;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 6;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 7;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 8;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 9;    Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
    [PSCustomObject]@{MainAlgorithm = "Ethash";          MinMemGb = 4;   Intensity = 10;   Params = "--algo ethash+eaglesong";      Vendor = @("NVIDIA");       ExtendInterval = 2; NH = $true; Fee = 3.00; SecondaryAlgorithm = "Eaglesong"; NH2 = $true} #Ethash+Eaglesong
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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)} | ForEach-Object {
            $First = $true
            
            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $Ethmining = $_.MainAlgorithm -match "^Ethash"

            $DualIntensity = $_.Intensity

            $MinMemGB = if ($Ethmining) {Get-EthDAGSize $Pools.$MainAlgorithm_Norm_0.CoinSymbol} elseif ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

            if ($SecondAlgorithm_Norm) {
                $Miner_Config = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)".Intensity
                if ($Miner_Config -and $Miner_Config -notcontains $DualIntensity) {$Miner_Device = $null}
            }

		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$MainAlgorithm_Norm.Name -notmatch "Nicehash") -and (-not $_.Coins -or $_.Coins -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $SecondAlgorithm_Norm -or ($Pools.$SecondAlgorithm_Norm.Host -and ($_.NH2 -or $Pools.$SecondAlgorithm_Norm.Name -notmatch "Nicehash") -and (-not $_.Coins2 -or $_.Coins2 -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)))) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)$(if ($DualIntensity -ne $null) {"-$($DualIntensity)"})"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
                        if ($_.Intensity -ne $null) {
                            $DeviceIntensitiesAll = " $($DualIntensity)"*($Miner_Device | Measure-Object).Count
                        }
                        $First = $false
                    }
                    $PersCoin = if ($MainAlgorithm_Norm -match "^Equihash") {Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"}
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    if ($SecondAlgorithm_Norm) {
                        $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll)$(if ($DualIntensity -ne $null) {" --dual_intensity$($DeviceIntensitiesAll)"}) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($Ethmining -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -ne "ethproxy") {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --dserver $($Pools.$SecondAlgorithm_Norm.Host) --dport $($SecondPool_Port) --duser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.SSL) {" --dssl 1"}) --watchdog 0 --pec 0 --nvml 0 $($_.Params)"
					        HashRates      = [PSCustomObject]@{
                                                $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                            }
					        API            = "Gminer"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = [PSCustomObject]@{
								                ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
								                ($SecondAlgorithm_Norm) = 0
                                              }
					        Uri            = $Uri
					        ManualUri      = $ManualUri
					        NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
				        }
                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($Ethmining -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -ne "ethproxy") {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --watchdog 0 --pec 0 --nvml 0 $($_.Params)"
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
					        API            = "Gminer"
					        Port           = $Miner_Port
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
					        Uri            = $Uri
					        ManualUri      = $ManualUri
					        NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
				        }
                    }
			    }
		    }
        }
    }
}