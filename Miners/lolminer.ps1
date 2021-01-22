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
$Version = "1.20"

if ($IsLinux) {
    $Path = ".\Bin\GPU-lolMiner\lolMiner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.20-lolminer/lolMiner_v1.20_Lin64.tar.gz"
} else {
    $Path = ".\Bin\GPU-lolMiner\lolMiner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.20-lolminer/lolMiner_v1.20_Win64.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                    MinMemGb = 3;   Params = "--algo BEAM-III";  Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #BeamHash III
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29b";                  MinMemGb = 6;   Params = "--algo CR29-40";   Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo29b
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29i";                  MinMemGb = 6;   Params = "--algo CR29-48";   Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckaroo29i
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";                  MinMemGb = 6;   Params = "--algo CR29-32";   Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo29s
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo30";                   MinMemGb = 7.6; Params = "--algo C30CTX";    Pers=$false; Fee=2.5; ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroo30
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";                   MinMemGb = 4;   Params = "--algo C31";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";                   MinMemGb = 4;   Params = "--algo C32";       Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #Cuckatoo32
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";                  MinMemGb = 6;   Params = "--algo C29D";      Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckarood29
    [PSCustomObject]@{MainAlgorithm = "Cuckaroom29";                  MinMemGb = 6;   Params = "--algo C29M";      Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD")} #Cuckaroom29
    [PSCustomObject]@{MainAlgorithm = "CuckooCycle";                  MinMemGb = 6;   Params = "--algo C29AE";     Pers=$false; Fee=2;   ExtendInterval = 2; Vendor = @("AMD","NVIDIA")} #CuckooCycle/AEternity
    [PSCustomObject]@{MainAlgorithm = "Equihash21x9";                 MinMemGb = 1;   Params = "--algo EQUI210_9"; Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "^Nicehash"} #Equihash 210,9
    [PSCustomObject]@{MainAlgorithm = "Equihash24x5";                 MinMemGb = 2;   Params = "--algo EQUI144_5"; ParamsAutoPers = "--coin AUTO144_5"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "^Nicehash"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash24x7";                 MinMemGb = 3;   Params = "--algo EQUI192_7"; ParamsAutoPers = "--coin AUTO192_7"; Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "^Nicehash"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x4";                MinMemGb = 3;   Params = "--coin ZEL";       Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD"); ExcludePoolName = "^Nicehash"} #Equihash 125,4,0
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5";                MinMemGb = 3;   Params = "--algo BEAM-I";    Pers=$true;  Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 150,5
    [PSCustomObject]@{MainAlgorithm = "EquihashR25x5x3";              MinMemGb = 3;   Params = "--algo BEAM-II";   Pers=$false; Fee=1;   ExtendInterval = 2; Vendor = @("AMD")} #Equihash 150,5,3
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; MinMemGB = 2;   Params = "--algo ETHASH";    Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD")} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; MinMemGB = 2;   Params = "--algo ETCHASH";   Pers=$false; Fee=0.7; ExtendInterval = 3; Vendor = @("AMD")} #Etchash
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
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            #Zombie-Mode since v1.11
            if ($_.DAG -and $Algorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGb -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGb
            }

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

			foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }
                    $PersCoin = if ($_.Pers) {Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto"}

                    $EthStratum = if ($Algorithm_Norm_0 -match $Global:RegexAlgoHasEthproxy) {
                        Switch ($Pools.$Algorithm_Norm.EthMode) {
                            "ethproxy" {"ETHPROXY"}
                            default {"ETHV1"}
                        }
                    }

                    if (-not $_.Pers -or $PersCoin -or $_.ParamsAutoPers) {
                        $Pool_Port  = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					    [PSCustomObject]@{
						    Name           = $Miner_Name
						    DeviceName     = $Miner_Device.Name
						    DeviceModel    = $Miner_Model
						    Path           = $Path
						    Arguments      = "--pool $($Pools.$Algorithm_Norm.Host):$($Pool_Port) --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.Worker) {" --worker $($Pools.$Algorithm_Norm.Worker)"}) --devices $($Miner_Device.Type_Mineable_Index -join ',') --apiport `$mport --tls $(if ($Pools.$Algorithm_Norm.SSL) {"on"} else {"off"}) --digits 2 --longstats 60 --shortstats 5 --connectattempts 3 $(if ($EthStratum) {"--ethstratum $($EthStratum) "})$(if ($PersCoin -and $PersCoin -ne "auto") {"--pers $($PersCoin) "})$(if ($PersCoin -eq "auto" -and $_.ParamsAutoPers) {$_.ParamsAutoPers} else {$_.Params})"
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
        })
    }
}
