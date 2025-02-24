using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No AMD/CPU/NVIDIA present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=5025783.0"
$Port = "333{0:d2}"
$DevFee = 1.0
$Cuda = "11.8"
$Version = "2024.3.2"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.3.2-ttminer/TT-Miner-2024.3.2.tar.gz"

} else {
    $Path = ".\Bin\NVIDIA-TTminer\TT-Miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2024.3.2-ttminer/TT-Miner-2024.3.2.zip"
}

$Commands = [PSCustomObject[]]@(
    #CPU
    [PSCustomObject]@{MainAlgorithm = "Flex";                        MinMemGB = 1;   Params = "-a Flex";          Vendor = @("CPU"); ExtendInterval = 2} #Flex
    [PSCustomObject]@{MainAlgorithm = "SpectreX";                    MinMemGB = 1;   Params = "-a SpectreX";      Vendor = @("CPU"); ExtendInterval = 2} #Spectre
    [PSCustomObject]@{MainAlgorithm = "XelisHashV2";                 MinMemGB = 1;   Params = "-a Xelis";         Vendor = @("CPU"); ExtendInterval = 2} #Xelis

    #GPU
    [PSCustomObject]@{MainAlgorithm = "Blake3Alephium";              MinMemGB = 2;   Params = "-a Blake3";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #Blake3Alephium
    [PSCustomObject]@{MainAlgorithm = "Ethash"        ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASH";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash2g"      ; DAG = $true; MinMemGB = 1;   Params = "-a ETHASH";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash3g"      ; DAG = $true; MinMemGB = 2;   Params = "-a ETHASH";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash4g"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASH";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "Ethash5g"      ; DAG = $true; MinMemGB = 4;   Params = "-a ETHASH";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash 
    [PSCustomObject]@{MainAlgorithm = "EthashB3"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASHB3";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #EthashB3
    [PSCustomObject]@{MainAlgorithm = "Etchash"       ; DAG = $true; MinMemGB = 3;   Params = "-a ETCHASH";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Etchash 
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory" ; DAG = $true; MinMemGB = 2;   Params = "-a ETHASH";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EvrProgPow"    ; DAG = $true; MinMemGB = 3;   Params = "-a EvrProgPow";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #EvrProgPow
    [PSCustomObject]@{MainAlgorithm = "FiroPow"       ; DAG = $true; MinMemGB = 3;   Params = "-a FiroPow";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "ZergPool|ZPool"} #FiroPow
    [PSCustomObject]@{MainAlgorithm = "SCCPow"        ; DAG = $true; MinMemGB = 3;   Params = "-a FiroPowSCC";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "ZergPool|ZPool"} #SCCPow
    [PSCustomObject]@{MainAlgorithm = "FishHash"      ; DAG = $true; MinMemGB = 3;   Params = "-a FishHash";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #FishHash/IRON
    [PSCustomObject]@{MainAlgorithm = "Take2"         ;              MinMemGB = 1;   Params = "-a Ghostrider";    Vendor = @("CPU","NVIDIA"); FaultTolerance = 10; ExtendInterval = 3; DevFee = 1.0} #Ghostrider
    [PSCustomObject]@{MainAlgorithm = "KawPow"        ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow2g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow3g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow4g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #KAWPOW
    [PSCustomObject]@{MainAlgorithm = "KawPow5g"      ; DAG = $true; MinMemGB = 3;   Params = "-a KawPow";        Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #KAWPOW
    #[PSCustomObject]@{MainAlgorithm = "MeowPow"       ; DAG = $true; MinMemGB = 3;   Params = "-c MEWC";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #MEOWPOW
    [PSCustomObject]@{MainAlgorithm = "Mike"          ;              MinMemGB = 1;   Params = "-a Mike";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DevFee = 2.0} #Mike
    [PSCustomObject]@{MainAlgorithm = "ProgPoWEPIC"   ; DAG = $true; MinMemGB = 3;   Params = "-c EPIC";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DevFee = 2.0} #ProgPoW (only EPIC left)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWSERO"   ; DAG = $true; MinMemGB = 3;   Params = "-c SERO";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #ProgPoWSero (SERO)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWVEIL"   ; DAG = $true; MinMemGB = 3;   Params = "-c VEIL";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #ProgPoWSero (VEIL)
    [PSCustomObject]@{MainAlgorithm = "ProgPoWZ"      ; DAG = $true; MinMemGB = 3;   Params = "-c ZANO";          Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #ProgPoWZ (ZANO)
    [PSCustomObject]@{MainAlgorithm = "SHA3d"         ;              MinMemGB = 2;   Params = "-a Sha3d";         Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #SHA3d
    [PSCustomObject]@{MainAlgorithm = "SHA3Solidity"  ;              MinMemGB = 2;   Params = "";                 Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Coins = @("EGAZ","ETI")} #SHA3Solidity
    [PSCustomObject]@{MainAlgorithm = "SHA256dt"      ;              MinMemGB = 2;   Params = "-a Sha256dt";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #SHA256dt
    [PSCustomObject]@{MainAlgorithm = "SHA512256d"    ;              MinMemGB = 2;   Params = "-a Sha512256d";    Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #Sha512256d
    [PSCustomObject]@{MainAlgorithm = "UbqHash"       ;              MinMemGB = 2.4; Params = "-a UBQHASH";       Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #Ubqhash
    [PSCustomObject]@{MainAlgorithm = "vProgPoW"      ; DAG = $true; MinMemGB = 3;   Params = "-a vProgPow";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2} #ProgPoWSero (VBK)

    #[PSCustomObject]@{MainAlgorithm = "EthashB3"      ; DAG = $true; MinMemGB = 3;   Params = "-a ETHASHB3";      Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; ExcludePoolName = "MiningRigRentals"; SecondaryAlgorithm = "SHA512256d"; SecondaryParams = "-a Sha512256d"} #EthashB3 + SHA512256d
)

$CoinSymbols = @("AKA","ALPH","ALT","ARL","AVS","BBC","BCH","BLACK","BNBTC","BTC","BTRM","BUT","CLO","CLORE","Coin","EGAZ","EGEM","ELH","EPIC","ETC","ETHF","ETHO","ETHW","ETI","ETP","EVOX","EVR","EXP","FIRO","FITA","FRENS","GRAMS","GSPC","HVQ","IRON","JGC","KAW","KCN","LAB","LTR","MEOW","MEWC","NAPI","NEOX","NOVO","OCTA","PAPRY","PRCO","REDE","RTH","RTM","RVN","RXD","SATO","SATOX","SCC","SERO","SPR","THOON","TTM","UBQ","VBK","VEIL","VKAX","VTE","XEL","XNA","YERB","ZANO","ZELS","ZIL","ZKBTC")
#$a = @($s -split "[\r\n]+" | Foreach-Object {$_ -replace "^[\w]+\s+" -split "[\s,;]+"} | Where-Object {$_ -ne ""} | Sort-Object -Unique) -join '","'

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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

$NVmax = 0
if ($Session.Config.CUDAVersion) {
    $Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name
    $NVmax = ($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Codec -eq "CUDA"} | Measure-Object -Property BusId_Type_Codec_Index).Count
}

if ($SaveDAG = $Session.Config.EnableMinersToSaveDAG) {
    $Session.SysInfo.Disks | Where-Object {$_.IsCurrent} | Foreach-Object {
        $SaveDAGUsed = 0
        $SaveDAGPath = Join-Path (Split-Path $Path) "DAGs"

        if (Test-Path $SaveDAGPath) {
            $SaveDAGUsed = [Decimal][Math]::Round((Get-ChildItem $SaveDAGPath -File -Filter "*.dag" | Foreach-Object {$_.Length} | Measure-Object -Sum).Sum / 1GB,1)
        }
        if ($_.FreeGB -lt (100 - $SaveDAGUsed)) {$SaveDAG = $false}
    }
}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $True
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $Miner_Fee = if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee}

            $ZilParams = ""

            if ($Miner_Vendor -ne "CPU" -and $Session.Config.Pools.Crazypool.EnableTTminerDual -and $Pools.ZilliqaCP) {
                if ($ZilWallet = $Pools.ZilliqaCP.Wallet) {
                    $ZilParams = " -cZ ZIL$(if ($Pools.ZilliqaCP.Worker -and $Pools.ZilliqaCP.User -notmatch "{workername" -and $Pools.ZilliqaCP.Pass -notmatch "{workername") {" -wZ $($Pools.ZilliqaCP.Worker)"}) -PZ $(if ($Pools.ZilliqaCP.SSL) {"ssl://"})$($Pools.ZilliqaCP.User)$(if ($Pools.ZilliqaCP.Pass) {":$($Pools.ZilliqaCP.Pass)"})@$($Pools.ZilliqaCP.Host):$($Pools.ZilliqaCP.Port)"
                }
            }

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
            }
        
            $All_MainAlgorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

		    foreach($Algorithm_Norm in $All_MainAlgorithms) {
                if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or (Test-VRAM $_ $MinMemGB)}

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.Coins -or $_.Coins -icontains $Pools.$Algorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoins -or $_.ExcludeCoins -inotcontains $Pools.$Algorithm_Norm.CoinSymbol)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = if ($Miner_Vendor -eq "CPU") {"-d $($Miner_Device.Index -join ' ') -cpu $($CPUThreads)"}
                                        elseif ($Miner_Vendor -eq "NVIDIA") {"-d $($Miner_Device.Type_Vendor_Index -join ' ') -cuda-order"}
                                        else {"-d $(@($Miner_Device.BusId_Type_Codec_Index | Foreach-Object {$_ + $NVmax}) -join ' ')"}
                        $First = $False
                    }

                    $Pool_Port = $Pools.$Algorithm_Norm.Port
                    if ($Pools.$Algorithm_Norm.Ports -ne $null) {
                        if ($Miner_Vendor -eq "CPU") {
                            if ($Pools.$Algorithm_Norm.Ports.CPU) {$Pool_Port = $Pools.$Algorithm_Norm.Ports.CPU}
                        } elseif ($Pools.$Algorithm_Norm.Ports.GPU) {$Pool_Port = $Pools.$Algorithm_Norm.Ports.GPU}
                    }

                    if ($Pools.$Algorithm_Norm.CoinSymbol -eq "EPIC") {
                        $Miner_Protocol = "epic$(if ($Pools.$Algorithm_Norm.SSL) {"+ssl"})://"
                    } elseif ($Pools.$Algorithm_Norm.EthMode -eq "ethproxy" -and ($Pools.$Algorithm_Norm.Host -notmatch "MiningRigRentals" -or $Algorithm_Norm_0 -ne "ProgPow")) {
                        $Miner_Protocol = "stratum1$(if ($Pools.$Algorithm_Norm.SSL) {"+ssl"})://"
                    } else {
                        $Miner_Protocol = "$(if ($Pools.$Algorithm_Norm.SSL) {"ssl://"})"
                    }
                    if ($Algorithm_Norm_0 -eq "SHA3Solidity") {$Miner_Protocol = ""}

                    $Pass = "$($Pools.$Algorithm_Norm.Pass)"
                    if ($Pass -and $Pools.$Algorithm_Norm.Host -match "C3pool|MoneroOcean") {
                        $Pass = $Pass -replace ":[^:]+~","~"
                    }

                    $Params = $_.Params
                    if ($ZilParams -ne "") {
                        $Params_Symbol = "$(if ($Pools.$Algorithm_Norm.CoinSymbol) {$Pools.$Algorithm_Norm.CoinSymbol} else {$Algorithm_Norm})".Substring(0,2).ToUpper()
                        $Params = $Params -replace "-c ","-c$($Params_Symbol) " -replace "-a ","-a$($Params_Symbol) " -replace "-w ","-w$($Params_Symbol)"
                    } else {
                        $Params_Symbol = ""
                    }

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "--api-bind 127.0.0.1:`$mport $($DeviceIDsAll)$(if ($_.DAG -and $SaveDAG) {" -dag-2disk"})$(if ($_.DAG) {" -daginfo"}) -o$($Params_Symbol) $($Miner_Protocol)$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u$($Params_Symbol) $(if ($Pools.$MainAlgorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User})$(if ($Pools.$MainAlgorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Pass -notmatch "{workername") {" -w$($Params_Symbol) $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pass) {" -p$($Params_Symbol) $($Pass)"})$(if ($Params -notmatch "-c" -and $Pools.$Algorithm_Norm.CoinSymbol -and $CoinSymbols -icontains $Pools.$Algorithm_Norm.CoinSymbol) {" -c$($Params_Symbol) $($Pools.$Algorithm_Norm.CoinSymbol)"})$($ZilParams) $($Params)"
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
        }
    }
}