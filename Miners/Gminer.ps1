using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://github.com/develsoftware/GMinerRelease/releases"
$Port = "329{0:d2}"
$DevFee = 2.0
$Cuda = "9.0"
#$Version = "2.37"

if ($IsLinux) {
    $Path = ".\Bin\GPU-Gminer\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.37-gminer/gminer_2_37_linux64.tar.xz"
    $Version = "2.37"
} else {
    $Path = ".\Bin\GPU-Gminer\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.38-gminer/gminer_2_38_windows64.zip"
    $Version = "2.38"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD, NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Aeternity";                    MinMemGb = 4;                     Params = "--algo aeternity";   Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true} #Cuckoo29/Aeternity
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                    MinMemGb = 3;                     Params = "--algo BeamHashIII"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; AutoPers = $false} #BeamHash3 (BEAM)
    [PSCustomObject]@{MainAlgorithm = "Cortex";                       MinMemGb = 8;                     Params = "--algo cortex";      Vendor = @("NVIDIA");       ExtendInterval = 2; NoCPUMining = $false; Fee = 5.0} #Cortex
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29b";                  MinMemGb = 4;                     Params = "--algo cuckaroo29b"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true;  Fee = 4.0} #Cuckaroo29b/TUBE (from July 29th 2020)
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29bfc";                MinMemGb = 4;                     Params = "--algo bfc";         Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true;  Fee = 3.0} #Equihash Cuckoo29/BFC
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";                  MinMemGb = 4;                     Params = "--algo swap";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true; ExcludePoolName = "^MoneroOcean"} #Cuckaroo29s/SWAP
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";                   MinMemGb = 8;                     Params = "--algo grin31";      Vendor = @("NVIDIA");       ExtendInterval = 2; NoCPUMining = $true} #Cuckatoo31/GRIN31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";                   MinMemGb = 6;                     Params = "--algo grin32";      Vendor = @("NVIDIA");       ExtendInterval = 2; NoCPUMining = $true} #Cuckatoo32/GRIN32
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";                  MinMemGb = 4;                     Params = "--algo cuckarood29"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true} #Cuckarood29 upto 01/16/2020
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29v";                 MinMemGb = 4;                     Params = "--algo cuckarood29v";Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true} #Cuckarood29v/MoneroV
    [PSCustomObject]@{MainAlgorithm = "Cuckarooz29";                  MinMemGb = 4;                     Params = "--algo cuckarooz29"; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; NoCPUMining = $true;  Fee = 3.0; ExcludeCoinSymbol = @("PMEER")} #Cuckarooz29/GRIN from 07/16/2020
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";                 MinMemGb = 2;                     Params = "--algo 144_5";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; AutoPers = $true} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";                MinMemGb = 2;                     Params = "--algo 125_4";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; AutoPers = $true} #Equihash 125,4/ZelHash
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";                 MinMemGb = 3.0;                   Params = "--algo 192_7";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; AutoPers = $true} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";                 MinMemGb = 0.5;                   Params = "--algo 210_9";       Vendor = @("NVIDIA");       ExtendInterval = 2; AutoPers = $true} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "EquihashVds";                  MinMemGb = 2;                     Params = "--algo vds";         Vendor = @("NVIDIA");       ExtendInterval = 2; AutoPers = $false} #Equihash 96,5 + Scrypt "VDS"
    [PSCustomObject]@{MainAlgorithm = "Etchash";         DAG = $true; MinMemGb = 3;                     Params = "--algo etchash";     Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 0.65; ExcludePoolName = ""} #Etchash
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGb = 3;                     Params = "--algo ethash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Fee = 0.65; ExcludePoolName = ""} #Ethash
    [PSCustomObject]@{MainAlgorithm = "KawPOW";          DAG = $true; MinMemGb = 3;                     Params = "--algo kawpow";      Vendor = @("NVIDIA");       ExtendInterval = 2; Fee = 1.00; ExcludePoolName = ""} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "ProgPoWSero";     DAG = $true; MinMemGb = 3;                     Params = "--algo sero";        Vendor = @("NVIDIA");       ExtendInterval = 2; ExcludePoolName = ""} #ProgPow Sero
    [PSCustomObject]@{MainAlgorithm = "ProgPoWZ";        DAG = $true; MinMemGb = 3;                     Params = "--algo progpowz";    Vendor = @("NVIDIA");       ExtendInterval = 2; ExcludePoolName = ""} #ProgPow Zano
    [PSCustomObject]@{MainAlgorithm = "vProgPoW";        DAG = $true; MinMemGb = 3;                     Params = "--algo vprogpow";    Vendor = @("NVIDIA");       ExtendInterval = 2; ExcludePoolName = ""} #ProgPow Veriblock
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
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)}).ForEach({
            $First = $true
            
            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $SecondAlgorithm_Norm = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $HasEthproxy = $MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy

            $DualIntensity = $_.Intensity

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
            
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

            if ($SecondAlgorithm_Norm) {
                $Miner_Config = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)".Intensity
                if ($Miner_Config -and $Miner_Config -notcontains $DualIntensity) {$Miner_Device = $null}
            }

		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Name -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $SecondAlgorithm_Norm -or ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.ExcludePoolName2 -or $Pools.$SecondAlgorithm_Norm.Name -notmatch $_.ExcludePoolName2) -and (-not $_.CoinSymbol2 -or $_.CoinSymbol2 -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol2 -or $_.ExcludeCoinSymbol2 -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)))) {
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
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll)$(if ($DualIntensity -ne $null) {" --dual_intensity$($DeviceIntensitiesAll)"}) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --dserver $($Pools.$SecondAlgorithm_Norm.Host) --dport $($SecondPool_Port) --duser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($Pools.$SecondAlgorithm_Norm.SSL) {" --dssl 1"}) --watchdog 0 --pec 0 --nvml 1 $($_.Params)"
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
                            ExcludePoolName= $_.ExcludePoolName
				        }
                    } else {
				        [PSCustomObject]@{
					        Name           = $Miner_Name
					        DeviceName     = $Miner_Device.Name
					        DeviceModel    = $Miner_Model
					        Path           = $Path
					        Arguments      = "--api `$mport --devices $($DeviceIDsAll) --server $($Pools.$MainAlgorithm_Norm.Host) --port $($Pool_Port)$(if ($HasEthproxy -and $Pools.$MainAlgorithm_Norm.EthMode -ne $null -and $Pools.$MainAlgorithm_Norm.EthMode -notin @("ethproxy","qtminer")) {" --proto stratum"}) --user $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($PersCoin -and ($_.AutoPers -or $PersCoin -ne "auto")) {" --pers $($PersCoin)"})$(if ($Pools.$MainAlgorithm_Norm.SSL) {" --ssl 1"}) --cuda $([int]($Miner_Vendor -eq "NVIDIA")) --opencl $([int]($Miner_Vendor -eq "AMD")) --watchdog 0 --pec 1 --nvml 1 $($_.Params)"
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
                            ExcludePoolName= $_.ExcludePoolName
				        }
                    }
			    }
		    }
        })
    }
}