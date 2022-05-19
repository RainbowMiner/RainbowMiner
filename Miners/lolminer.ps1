using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "317{0:d2}"
$Cuda = "10.0"
$DevFee = 1.0
$Version = "1.51"

if ($IsLinux) {
    $Path = ".\Bin\GPU-lolMiner\lolMiner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.51-lolminer/lolMiner_v1.51_Lin64.tar.gz"
} else {
    $Path = ".\Bin\GPU-lolMiner\lolMiner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.51-lolminer/lolMiner_v1.51_Win64.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";                   MinMemGb = 2;   Params = "--algo AUTOLYKOS2"; Pers=$false; Fee=1.5; ExtendInterval = 3; Vendor = @("AMD","NVIDIA")} #Autolykos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                    MinMemGb = 3;   Params = "--algo BEAM-III";   Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #BeamHash III
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29b";                  MinMemGb = 6;   Params = "--algo CR29-40";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo29b
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";                  MinMemGb = 6;   Params = "--algo CR29-32";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo29s
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo30";                   MinMemGb = 7.6; Params = "--algo C30CTX";     Pers=$false; Fee=2.5; ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo30
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";                   MinMemGb = 4;   Params = "--algo C31";        Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";                   MinMemGb = 4;   Params = "--algo C32";        Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo32
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";                  MinMemGb = 6;   Params = "--algo C29D";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckarood29
    [PSCustomObject]@{MainAlgorithm = "Cuckaroom29";                  MinMemGb = 6;   Params = "--algo C29M";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroom29
    [PSCustomObject]@{MainAlgorithm = "CuckooCycle";                  MinMemGb = 6;   Params = "--algo C29AE";      Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #CuckooCycle/AEternity
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";                 MinMemGb = 1;   Params = "--algo EQUI210_9";  Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "Nicehash"} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";                 MinMemGb = 2;   Params = "--algo EQUI144_5";  ParamsAutoPers = "--coin AUTO144_5"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "Nicehash"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";                 MinMemGb = 3;   Params = "--algo EQUI192_7";  ParamsAutoPers = "--coin AUTO192_7"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "Nicehash"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";                MinMemGb = 3;   Params = "--coin ZEL";        Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "Nicehash"} #Equihash 125,4,0
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5";                MinMemGb = 3;   Params = "--algo BEAM-I";     Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 150,5
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3";              MinMemGb = 3;   Params = "--algo BEAM-II";    Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 150,5,3
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1";   Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); DualZIL = "ETC"} #Etchash
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1 --dualmode TONDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; OpenCLArch = "P"} #Etchash + SHA256ton
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3"; OpenCLArch = "P"} #Etchash + Blake3
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); DualZIL = "ETH"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode TONDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; OpenCLArch = "P"} #Ethash + SHA256ton
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3"; OpenCLArch = "P"} #Ethash + Blake3
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1";    Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); DualZIL = "ETH"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode TONDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; OpenCLArch = "P"} #Ethash for low memory coins + SHA256ton
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";    Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3"; OpenCLArch = "P"} #Ethash for low memory coins + Blake3
    [PSCustomObject]@{MainAlgorithm = "SHA256ton";                    MinMemGb = 2;   Params = "--algo TON";        Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #SHA256ton/TON
    [PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1";   Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); DualZIL = "ETH"} #Ubqhash
    [PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1 --dualmode TONDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "SHA256ton"; OpenCLArch = "P"} #Ubqhash + SHA256ton
    [PSCustomObject]@{MainAlgorithm = "UbqHash";         DAG = $true; MinMemGB = 2;   Params = "--algo UBQHASH --disable-dag-verify 1 --dualmode ALEPHDUAL";   Pers=$false; Fee=1.0; ExtendInterval = 3; Vendor = @("AMD","NVIDIA"); SecondAlgorithm = "Blake3"; OpenCLArch = "P"} #Ubqhash + Blake3
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

$OpenCLArch_Types = [PSCustomObject]@{
    "A" = @("Ampere")
    "T" = @("Turing","Ampere")
    "P" = @("Pascal","Turing","Ampere")
}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

$WatchdogParams = if ($Session.Config.RebootOnGPUFailure -and $Session.Config.EnableRestartComputer) {"--watchdog script --watchdogscript '$(Join-Path $Session.MainPath "$(if ($IsLinux) {"reboot.sh"} else {"Reboot.bat"})")'"} else {"--watchdog exit"}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

			$SecondAlgorithm = $_.SecondAlgorithm
			$SecondAlgorithm_Norm_0 = if ($_.SecondAlgorithm) {Get-Algorithm $_.SecondAlgorithm} else {$null}

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            #Zombie-Mode since v1.11
            if ($_.DAG -and $MainAlgorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGb -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGb
            }

            $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGB)}

            if ($_.OpenCLArch -ne $null -and $_.Vendor -eq "NVIDIA") {
                $OpenCLArch = $OpenCLArch_Types."$($_.OpenCLArch)"
                if (-not ($Miner_Device | Where-Object {$_.OpenCL.Architecture -in $OpenCLArch} | Measure-Object).Count) {
                    #no mining, if not at least one GPU is available
                    $Miner_Device = $null
                }
            }

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
				if ($Miner_Device -and $Pools.$MainAlgorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll  = $Miner_Device.BusId_Type_Mineable_Index -join ',' #"$($Miner_Device.BusId -join ',') --devicesbypcie"
                        $DeviceLHRsAll = if ($Miner_Vendor -eq "NVIDIA") {($Miner_Device | Foreach-Object {if ($_.IsLHR) {"auto"} else {"off"}}) -join ','}
                        $First = $false
                    }
                    $PersCoin = if ($_.Pers) {Get-EquihashCoinPers $Pools.$MainAlgorithm_Norm.CoinSymbol -Default "auto"}

                    $EthStratum = if ($MainAlgorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy) {
                        Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                            "ethproxy" {"ETHPROXY"}
                            "qtminer" {if ($Pools.$MainAlgorithm_Norm.Host -match "miningrigrentals") {"ETHPROXY"} else {"ETHV1"}}
                            default {"ETHV1"}
                        }
                    }

                    $ZilParams = ""

                    if ($Session.Config.Pools.Ezil.EnableLolminerDual -and $_.DualZIL -and $Pools."Zilliqa$($_.DualZIL)" -and $Pools."Zilliqa$($_.DualZIL)".EthMode -eq $Pools.$MainAlgorithm_Norm.EthMode) {
                        $ZilWallet = $Pools."Zilliqa$($_.DualZIL)".Wallet
                        $ZilPool   = "$($Pools."Zilliqa$($_.DualZIL)".Host):$($Pools."Zilliqa$($_.DualZIL)".Port)"
                        if ($ZilWallet -and $ZilWallet) {
                            $EthWallet = if ($Pools.$MainAlgorithm_Norm.Wallet -match "^0x") {$Pools.$MainAlgorithm_Norm.Wallet} elseif ($_.DualZIL -eq "ETH") {"0xaaD1d2972f99A99248464cdb075B28697d4d8EEd"} else {"0x7f3E62e5bb0601bA52f0813Cb818279f40aB14BC"}
                            $ZilParams = " $(if (($Miner_Device.OpenCL.GlobalMemSizeGB | Measure-Object -Minimum).Minimum -ge 6) {"--enablezilcache"}) --dualmode zil --dualpool $($ZilPool) --dualuser $($EthWallet).$($ZilWallet)"
                        }
                    }

                    if (-not $_.Pers -or $PersCoin -or $_.ParamsAutoPers) {

                        $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                        $Pool_Host = if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "^[^/]+/.+$") {"$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)"} else {$Pools.$MainAlgorithm_Norm.Host}
                        $Pool_User = if ($Pools.$MainAlgorithm_Norm.Host -match "miningrigrentals") {$Pools.$MainAlgorithm_Norm.User -replace "\.","*"} else {$Pools.$MainAlgorithm_Norm.User}

                        $Pool_Arguments = if (-not $_.SecondAlgorithm -and $Session.Config.Pools.Ezil.EnableLolminerDual -and $_.DualZIL -and $Pools."Zilliqa$($_.DualZIL)" -and $Pools."Zilliqa$($_.DualZIL)".EthMode -eq $Pools.$MainAlgorithm_Norm.EthMode) {
                            $ZilWallet = $Pools."Zilliqa$($_.DualZIL)".Wallet
                            $ZilPool   = "$($Pools."Zilliqa$($_.DualZIL)".Host):$($Pools."Zilliqa$($_.DualZIL)".Port)"
                            if ($ZilPool -and $ZilWallet) {
                                $EthStratum = Switch ($Pools."Zilliqa$($_.DualZIL)".EthMode) {
                                        "ethproxy" {"ETHPROXY"}
                                        default {"ETHV1"}
                                    }
                                $EthWallet = if ($Pools.$MainAlgorithm_Norm.Wallet -match "^0x") {$Pools.$MainAlgorithm_Norm.Wallet} elseif ($_.DualZIL -eq "ETH") {"0xaaD1d2972f99A99248464cdb075B28697d4d8EEd"} else {"0x7f3E62e5bb0601bA52f0813Cb818279f40aB14BC"}
                                "--pool $($ZilPool) --user $($EthWallet).$($ZilWallet) --tls $(if ($Pools."Zilliqa$($_.DualZIL)".SSL) {"on"} else {"off"}) $(if (($Miner_Device.OpenCL.GlobalMemSizeGB | Measure-Object -Minimum).Minimum -ge 6) {"--enablezilcache"}) --dualmode zil --dualpool $(if ($Pools.$MainAlgorithm_Norm.SSL) {"tls://"})$($Pool_Host) --dualuser $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --dualpass $($Pools.$MainAlgorithm_Norm.Pass)"})"
                            }
                        }
                        if (-not $Pool_Arguments) {
                            $Pool_Arguments = "--pool $(if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.Protocol) {"$($Pools.$MainAlgorithm_Norm.Protocol)://"})$($Pool_Host) --user $($Pool_User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($MainAlgorithm_Norm_0 -ne "SHA256ton") {" --tls $(if ($Pools.$MainAlgorithm_Norm.SSL) {"on"} else {"off"})"})"
                        }

                        if ($SecondAlgorithm_Norm_0) {

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                    $SecondPool_Host = if ($SecondPool_Port -and $Pools.$SecondAlgorithm_Norm.Host -notmatch "^[^/]+/.+$") {"$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port)"} else {$Pools.$SecondAlgorithm_Norm.Host}

                                    $SecondPool_Arguments = "--dualpool $(if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.Protocol) {"$($Pools.$SecondAlgorithm_Norm.Protocol)://"})$($SecondPool_Host) --dualuser $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --dualpass $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($SecondAlgorithm_Norm_0 -ne "SHA256ton") {" --dualtls $(if ($Pools.$SecondAlgorithm_Norm.SSL) {"on"} else {"off"})"})"

                                    $TonMode = if ($SecondAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$SecondAlgorithm_Norm.EthMode) {
                                        Switch ($Pools.$SecondAlgorithm_Norm.EthMode) {
                                            "icemining" {6}
                                            "toncoinpool" {3}
                                            "tonpool" {2}
                                        }
                                    }

					                [PSCustomObject]@{
						                Name           = $Miner_Name
						                DeviceName     = $Miner_Device.Name
						                DeviceModel    = $Miner_Model
						                Path           = $Path
						                Arguments      = "$($Pool_Arguments)$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) $($SecondPool_Arguments)$(if ($TonMode) {" --ton-mode $($TonMode)"})$(if ($Pools.$SecondAlgorithm_Norm.Worker) {" --dualworker $($Pools.$SecondAlgorithm_Norm.Worker)"}) --devices $($DeviceIDsAll) --apiport `$mport --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $(if ($DeviceLHRsAll) {"--lhrtune $($DeviceLHRsAll) "})$(if ($EthStratum) {"--ethstratum $($EthStratum) "})$(if ($PersCoin -and $PersCoin -ne "auto") {"--pers $($PersCoin) "})$($WatchdogParams) $(if ($PersCoin -eq "auto" -and $_.ParamsAutoPers) {$_.ParamsAutoPers} else {$_.Params})"
						                HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                            $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                         }
						                API            = "Lol"
						                Port           = $Miner_Port
                                        FaultTolerance = $_.FaultTolerance
					                    ExtendInterval = $_.ExtendInterval
                                        Penalty        = 0
							            DevFee         = [PSCustomObject]@{
                                                        ($MainAlgorithm_Norm) = $_.Fee
                                                        ($SecondAlgorithm_Norm) = 0
							                        }
						                Uri            = $Uri
						                ManualUri      = $ManualUri
                                        Version        = $Version
                                        PowerDraw      = 0
                                        BaseName       = $Name
                                        BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        ExcludePoolName = $_.ExcludePoolName
					                }
                                }
                            }

                        } else {

                            $TonMode = if ($MainAlgorithm_Norm_0 -eq "SHA256ton" -and $Pools.$MainAlgorithm_Norm.EthMode) {
                                Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                                    "icemining" {6}
                                    "toncoinpool" {3}
                                    "tonpool" {2}
                                }
                            }

					        [PSCustomObject]@{
						        Name           = $Miner_Name
						        DeviceName     = $Miner_Device.Name
						        DeviceModel    = $Miner_Model
						        Path           = $Path
						        Arguments      = "$($Pool_Arguments)$(if ($TonMode) {" --ton-mode $($TonMode)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) --devices $($DeviceIDsAll) --apiport `$mport --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $(if ($DeviceLHRsAll) {"--lhrtune $($DeviceLHRsAll) "})$(if ($EthStratum) {"--ethstratum $($EthStratum) "})$(if ($PersCoin -and $PersCoin -ne "auto") {"--pers $($PersCoin) "})$($WatchdogParams) $(if ($PersCoin -eq "auto" -and $_.ParamsAutoPers) {$_.ParamsAutoPers} else {$_.Params})"
						        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
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
                                BaseAlgorithm  = $MainAlgorithm_Norm_0
                                Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                ListDevices    = "--list-devices"
                                ExcludePoolName = $_.ExcludePoolName
					        }
                        }
                    }
				}
			}
        })
    }
}
