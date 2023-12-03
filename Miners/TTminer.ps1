using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "333{0:d2}"
$DevFee = 1.0
$Cuda = "11.8"
$Version = "2023.4.3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2023.4.3-ttminer/TT-Miner-2023.4.3.tar.gz"

} else {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2023.4.3-ttminer/TT-Miner-2023.4.3.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Blake3Alephium";              MinMemGB = 2;   Params = "-a Blake3";        ExtendInterval = 2} #Blake3Alephium
    [PSCustomObject]@{MainAlgorithm = "Ethash"        ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASH";        ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash2g"      ; DAG = $true; MinMemGB = 1;   Params = "-a ETHASH";        ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash3g"      ; DAG = $true; MinMemGB = 2;   Params = "-a ETHASH";        ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash4g"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASH";        ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash5g"      ; DAG = $true; MinMemGB = 4;   Params = "-a ETHASH";        ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "EthashB3"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASHB3";      ExtendInterval = 2} #EthashB3
    [PSCustomObject]@{MainAlgorithm = "Etchash"       ; DAG = $true; MinMemGB = 3;   Params = "-a ETCHASH";       ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Etchash 
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory" ; DAG = $true; MinMemGB = 2;   Params = "-a ETHASH";      ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EvrProgPow"    ; DAG = $true; MinMemGB = 3;   Params = "-a EvrProgPow";    ExtendInterval = 2} #EvrProgPow
    [PSCustomObject]@{MainAlgorithm = "FiroPow"       ; DAG = $true; MinMemGB = 3;   Params = "-a FiroPow";       ExtendInterval = 2; ExcludeCoins = @("SCC")} #FiroPow
    [PSCustomObject]@{MainAlgorithm = "FiroPow"       ; DAG = $true; MinMemGB = 3;   Params = "-a FiroPowSCC";    ExtendInterval = 2; Coins = @("SCC")} #FiroPowSCC
    [PSCustomObject]@{MainAlgorithm = "Take2"         ;              MinMemGB = 1;   Params = "-a Ghostrider";    ExtendInterval = 2; DevFee = 1.0} #Ghostrider
    [PSCustomObject]@{MainAlgorithm = "KawPow"        ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow2g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow3g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow4g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow5g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "Mike"          ;              MinMemGB = 1;   Params = "-a Mike";          ExtendInterval = 2; DevFee = 2.0} #Mike
    [PSCustomObject]@{MainAlgorithm = "ProgPoWEPIC"   ; DAG = $true; MinMemGB = 3;   Params = "-c EPIC";          ExtendInterval = 2; DevFee = 2.0} #ProgPoW (only EPIC left)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWSERO"   ; DAG = $true; MinMemGB = 3;   Params = "-c SERO";          ExtendInterval = 2} #ProgPoWSero (SERO)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWVEIL"   ; DAG = $true; MinMemGB = 3;   Params = "-c VEIL";          ExtendInterval = 2} #ProgPoWSero (VEIL)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWZ"      ; DAG = $true; MinMemGB = 3;   Params = "-c ZANO";          ExtendInterval = 2} #ProgPoWZ (ZANO)
    [PSCustomObject]@{MainAlgorithm = "SHA3d"         ;              MinMemGB = 2;   Params = "-a Sha3d";         ExtendInterval = 2} #SHA3d
    [PSCustomObject]@{MainAlgorithm = "SHA3Solidity"  ;              MinMemGB = 2;   Params = "";                 ExtendInterval = 2; Coins = @("EGAZ","ETI")} #SHA3Solidity
    [PSCustomObject]@{MainAlgorithm = "SHA256dt"      ;              MinMemGB = 2;   Params = "-a Sha256dt";      ExtendInterval = 2} #SHA256dt
    [PSCustomObject]@{MainAlgorithm = "SHA512256d"    ;              MinMemGB = 2;   Params = "-a Sha512256d";    ExtendInterval = 2} #Sha512256d
    [PSCustomObject]@{MainAlgorithm = "UbqHash"       ;              MinMemGB = 2.4; Params = "-a UBQHASH";       ExtendInterval = 2} #Ubqhash
    [PSCustomObject]@{MainAlgorithm = "vProgPoW"      ; DAG = $true; MinMemGB = 3;   Params = "-a vProgPow";      ExtendInterval = 2} #ProgPoWSero (VBK)

    #[PSCustomObject]@{MainAlgorithm = "EthashB3"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASHB3";      ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "SHA512256d"; SecondaryParams = "-a Sha512256d"} #EthashB3 + SHA512256d
)

$CoinSymbols = @("AKA","ALPH","ALT","ARL","AVS","BBC","BCH","BLACK","BTC","BTRM","BUT","CLO","CLORE","EGEM","ELH","EPIC","ETC","ETHF","ETHO","ETHW","EGAZ","ETI","ETP","EVOX","EVR","EXP","FIRO","FITA","FRENS","GRAMS","GSPC","HVQ","JGC","KAW","KCN","KIIRO","LAB","LTR","MEWC","NAPI","NEOX","NOVO","OCTA","PAPRY","PRCO","REDE","RTH","RTM","RVN","RXD","SATO","SATOX","SCC","SERO","THOON","TTM","UBQ","VBK","VEIL","VKAX","VTE","XNA","YERB","ZANO","ZELS","ZIL")

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
        $First = $True
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $Miner_Fee = if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee}

        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

        $Miner_Device = $Device.Where({Test-VRAM $_ $MinMemGB})

        $ZilParams = ""

        if ($Session.Config.Pools.Crazypool.EnableTTminerDual -and $Pools.ZilliqaCP) {
            if ($ZilWallet = $Pools.ZilliqaCP.Wallet) {
                $ZilParams = " -cz ZIL$(if ($Pools.ZilliqaCP.Worker -and $Pools.ZilliqaCP.User -notmatch "{workername" -and $Pools.ZilliqaCP.Pass -notmatch "{workername") {" -wz $($Pools.ZilliqaCP.Worker)"}) -Pz $(if ($Pools.ZilliqaCP.SSL) {"ssl://"})$($Pools.ZilliqaCP.User)$(if ($Pools.ZilliqaCP.Pass) {":$($Pools.ZilliqaCP.Pass)"})@$($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port)"
            }
        }
        
		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.Coins -or $_.Coins -icontains $Pools.$Algorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoins -or $_.ExcludeCoins -inotcontains $Pools.$Algorithm_Norm.CoinSymbol) -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $Miner_Protocol = "stratum$(if ($Pools.$Algorithm_Norm_0.EthMode -eq "ethproxy" -and ($Pools.$Algorithm_Norm_0.Host -notmatch "MiningRigRentals" -or $Algorithm_Norm_0 -ne "ProgPow")) {"1"})+$(if ($Pools.$Algorithm_Norm_0.SSL) {"ssl"} else {"tcp"})://"
                    if ($Algorithm_Norm -eq "SHA3Solidity") {$Miner_Protocol = ""}
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
                    $First = $False
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                $Pass = "$($Pools.$Algorithm_Norm.Pass)"
                if ($Pass -and $Pools.$Algorithm_Norm.Host -match "C3pool|MoneroOcean") {
                    $Pass = $Pass -replace ":[^:]+~","~"
                }

                $Params = $_.Params
                if ($ZilParams -ne "") {
                    $Params_Symbol = "$(if ($Pools.$Algorithm_Norm.CoinSymbol) {$Pools.$Algorithm_Norm.CoinSymbol} else {$Algorithm_Norm})".Substring(0,2).ToLower()
                    $Params = $Params -replace "-c ","-c$($Params_Symbol) " -replace "-a ","-a$($Params_Symbol) " -replace "-w ","-w$($Params_Symbol)"
                } else {
                    $Params_Symbol = ""
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--api-bind 127.0.0.1:`$mport -d $($DeviceIDsAll)$(if ($_.DAG) {" -dag-2disk -daginfo"}) -P$($Params_Symbol) $($Miner_Protocol)$(if ($Pools.$MainAlgorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User})$(if ($Pools.$MainAlgorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Pass -notmatch "{workername") {".$($Pools.$Algorithm_Norm.Worker)"})$(if ($Pass) {":$($Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)$(if ($Params -notmatch "-c" -and $Pools.$Algorithm_Norm.CoinSymbol -and $CoinSymbols -icontains $Pools.$Algorithm_Norm.CoinSymbol) {" -c$($Params_Symbol) $($Pools.$Algorithm_Norm.CoinSymbol)"})$($ZilParams) $($Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week)}
					API            = "Claymore"
					Port           = $Miner_Port                
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $Miner_Fee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ExcludePoolName= $_.ExcludePoolName
				}
			}
		}
    })
}