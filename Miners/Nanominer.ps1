using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualURI = "https://github.com/nanopool/nanominer/releases"
$Port = "234{0:d2}"
$Cuda = "10.0"
$DevFee = 3.0
$Version = "3.8.5"

if ($IsLinux) {
    $Path = ".\Bin\ANY-Nanominer\nanominer"
    $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.5-nanominer/nanominer-linux-3.8.5.tar.gz"
} else {
    $Path = ".\Bin\ANY-Nanominer\nanominer.exe"
    $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.5-nanominer/nanominer-windows-3.8.5.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos";                    Params = ""; MinMemGb = 2;  Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; DevFee = 2.5; DualZIL = $true} #Autolycos/Ergo
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo30";                   Params = ""; MinMemGb = 14; Vendor = @("AMD");                  ExtendInterval = 2; DevFee = 5.0} #Cuckaroo30/Cortex
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; Params = ""; MinMemGb = 1;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; Params = ""; MinMemGb = 4;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA");                  ExtendInterval = 2; DevFee = 1.0; DualZIL = $true} #EtcHash
    [PSCustomObject]@{MainAlgorithm = "EvrProgPow";      DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; DevFee = 2.0; DualZIL = $true} #EvrProgPow/EVR
    [PSCustomObject]@{MainAlgorithm = "FiroPow";         DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; DevFee = 1.0; DualZIL = $true; ZombieMode = $true} #FiroPOW
    [PSCustomObject]@{MainAlgorithm = "heavyhash";                    Params = ""; MinMemGb = 2;  Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; DevFee = 1.0} #kHeavyHash/KAS
    [PSCustomObject]@{MainAlgorithm = "KawPow";          DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; DevFee = 2.0; DualZIL = $true} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "Octopus";         DAG = $true; Params = ""; MinMemGb = 5;  Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; DevFee = 2.0; DualZIL = $true} #Octopus/Conflux
    [PSCustomObject]@{MainAlgorithm = "RandomX";                      Params = ""; MinMemGb = 3;  Vendor = @("CPU");                  ExtendInterval = 2; DevFee = 2.0} #RandomX
    [PSCustomObject]@{MainAlgorithm = "Verushash";                    Params = ""; MinMemGb = 3;  Vendor = @("CPU");                  ExtendInterval = 2; DevFee = 2.0; CPUFeatures = @("avx","aes"); ExcludePoolName="LuckPool"} #Verushash
    [PSCustomObject]@{MainAlgorithm = "UbqHash";                      Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; Coins = @("UBQ"); ExcludePoolName = "F2Pool"} #UbqHash
    [PSCustomObject]@{MainAlgorithm = "Verthash";                     Params = ""; MinMemGb = 2;  Vendor = @("AMD");                  ExtendInterval = 2; DevFee = 1.0} #Verthash

    # Dual mining
    [PSCustomObject]@{MainAlgorithm = "autolykos";                    Params = ""; MinMemGb = 2;  Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; DevFee = 2.5; DualZIL = $true; SecondaryAlgorithm = "heavyhash"} #Autolycos/Ergo + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "Ethash";          DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash + kHeavyHash
    [PSCustomObject]@{MainAlgorithm = "Ethash2g";        DAG = $true; Params = ""; MinMemGb = 1;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "Ethash3g";        DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "Ethash4g";        DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "Ethash5g";        DAG = $true; Params = ""; MinMemGb = 4;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; Params = ""; MinMemGb = 2;  Vendor = @("AMD","INTEL","NVIDIA");          ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; DualZIL = $true; ExcludePoolName = "F2Pool"; SecondaryAlgorithm = "heavyhash"} #Ethash for low memory coins + kHeavyhash/KAS
    [PSCustomObject]@{MainAlgorithm = "EtcHash";         DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD");                  ExtendInterval = 2; DevFee = 1.0; DualZIL = $true; SecondaryAlgorithm = "heavyhash"} #EtcHash + kHeavyhash/KAS

)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","INTEL","NVIDIA")
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

foreach ($Miner_Vendor in @("AMD","CPU","INTEL","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and ($Miner_Vendor -ne "CPU" -or -not $_.CPUFeatures -or ($Global:GlobalCPUInfo.Features -and -not (Compare-Object @($Global:GlobalCPUInfo.Features.Keys) $_.CPUFeatures | Where-Object SideIndicator -eq "=>" | Measure-Object).Count))}).ForEach({
            $First = $true

            $MainAlgorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
            $SecondAlgorithm = $_.SecondaryAlgorithm
            
            $MainAlgorithm_Norm_0 = Get-Algorithm "$(if ($MainAlgorithm -eq "heavyhash") {"kHeavyHash"} else {$MainAlgorithm})"
            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm "$(if ($SecondAlgorithm -eq "heavyhash") {"kHeavyHash"} else {$SecondAlgorithm})"} else {$null}

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
            }

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            if ($_.ZombieMode -and -not $_.NoMemCalcCheck -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGB
            }

            $Miner_Device = $Device.Where({$Miner_Vendor -eq "CPU" -or (($MainAlgorithm_Norm_0 -ne "Cuckaroo30" -or $_.Model -eq "RX57016GB") -and ($Miner_Vendor -ne "NVIDIA" -or $Cuda -match "^11" -or $_.Model -notmatch "^RTX30") -and (Test-VRAM $_ $MinMemGb))})

            $All_MainAlgorithms = if ($Miner_Vendor -eq "CPU") {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")} else {@($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")}
            $All_SecondAlgorithms = if ($SecondAlgorithm_Norm_0) {if ($Miner_Vendor -eq "CPU") {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)")} else {@($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")}} else {$null}

            foreach($MainAlgorithm_Norm in $All_MainAlgorithms) {
                if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.Coins -or ($Pools.$MainAlgorithm_Norm.CoinSymbol -and $_.Coins -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol)) -and (-not $Pools.$MainAlgorithm_Norm.SSL -or -not $Pools.$MainAlgorithm_Norm.SSLSelfSigned)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                        $ZilWallet = if ($Session.Config.Pools.Ezil.EnableNanominerDual -and $_.DualZIL -and $Pools.ZilliqaETH -and $Pools.ZilliqaETH.EthMode -eq $Pools.$MainAlgorithm_Norm.EthMode) {
                            [PSCustomObject]@{
                                    Algo      = "zil"
                                    Host      = $Pools.ZilliqaETH.Host
                                    Port      = $Pools.ZilliqaETH.Port
                                    SSL       = $Pools.ZilliqaETH.SSL
                                    Wallet    = $Pools.ZilliqaETH.Wallet
                                    Worker    = "{workername:$($Pools.ZilliqaETH.Worker)}"
                                    Pass      = $Pools.ZilliqaETH.Pass
                                    Email     = $Pools.ZilliqaETH.Email
                            }
                        } else {$null}
                    }
                    $Pool_Port = if ($Miner_Vendor -ne "CPU" -and $Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    $Wallet    = if ($Pools.$MainAlgorithm_Norm.Wallet) {$Pools.$MainAlgorithm_Norm.Wallet} else {$Pools.$MainAlgorithm_Norm.User}

                    $PaymentId = $null
                    if ($Wallet -match "^(.+?)[\.\+]([0-9a-f]{16,})") {
                        $Wallet    = $Matches[1]
                        $PaymentId = $Matches[2]
                    } elseif ($MainAlgorithm_Norm -match "^RandomHash") {
                        $PaymentId = "0"
                    }

                    $MainCoin = $Pools.$MainAlgorithm_Norm.CoinSymbol
                    $MainCoin_Data = Get-Coin $MainCoin
                    if ($MainCoin_Data.Algo -ne $MainAlgorithm_Norm) {$MainCoin = $null}
                    
                    if ($All_SecondAlgorithms) {

                        $Miner_Name_Dual = $Miner_Name

                        foreach($SecondAlgorithm_Norm in $All_SecondAlgorithms) {
			                if ($Pools.$SecondAlgorithm_Norm.Host -and (-not $_.CoinSymbols -or $Pools.$SecondAlgorithm_Norm.CoinSymbol -in $_.CoinSymbols) -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.ExcludeYiimp -or -not $Session.PoolsConfigDefault."$($Pools.$SecondAlgorithm_Norm_0.Name)".Yiimp)) {

                                $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index) {$Pools.$SecondAlgorithm_Norm.Ports.$Pool_Port_Index} else {$Pools.$SecondAlgorithm_Norm.Port}
                                $SecondWallet    = if ($Pools.$SecondAlgorithm_Norm.Wallet) {$Pools.$SecondAlgorithm_Norm.Wallet} else {$Pools.$SecondAlgorithm_Norm.User}

                                $SecondPaymentId = $null
                                if ($Wallet -match "^(.+?)[\.\+]([0-9a-f]{16,})") {
                                    $Wallet    = $Matches[1]
                                    $SecondPaymentId = $Matches[2]
                                } elseif ($SecondAlgorithm_Norm -match "^RandomHash") {
                                    $SecondPaymentId = "0"
                                }

                                $SecondCoin = $Pools.$MainAlgorithm_Norm.CoinSymbol
                                $SecondCoin_Data = Get-Coin $MainCoin
                                if ($SecondCoin_Data.Algo -ne $SecondAlgorithm_Norm) {$SecondCoin = $null}

                                $Arguments = [PSCustomObject]@{
                                    Algorithms = @(
                                        [PSCustomObject]@{
                                            Algo      = $MainAlgorithm
                                            Coin      = $MainCoin
                                            Host      = $Pools.$MainAlgorithm_Norm.Host
                                            Port      = $Pool_Port
                                            SSL       = $Pools.$MainAlgorithm_Norm.SSL
                                            Wallet    = $Wallet
                                            PaymentId = $PaymentId
                                            Worker    = "{workername:$($Pools.$MainAlgorithm_Norm.Worker)}"
                                            Pass      = $Pools.$MainAlgorithm_Norm.Pass
                                            Email     = $Pools.$MainAlgorithm_Norm.Email
                                        }
                                        [PSCustomObject]@{
                                            Algo      = $SecondAlgorithm
                                            Coin      = $SecondCoin
                                            Host      = $Pools.$SecondAlgorithm_Norm.Host
                                            Port      = $SecondPool_Port
                                            SSL       = $Pools.$SecondAlgorithm_Norm.SSL
                                            Wallet    = $SecondWallet
                                            PaymentId = $SecondPaymentId
                                            Worker    = "{workername:$($Pools.$SecondAlgorithm_Norm.Worker)}"
                                            Pass      = $Pools.$SecondAlgorithm_Norm.Pass
                                            Email     = $Pools.$SecondAlgorithm_Norm.Email
                                        }
                                    )                            

                                    Devices   = if ($Miner_Vendor -ne "CPU") {$Miner_Device.BusId_Type_Mineable_Index} else {$null}
                                    LHR       = "$(if ($Miner_Vendor -eq "NVIDIA" -and $MainAlgorithm_Norm -match "^Etc?hash") {($Miner_Device | Foreach-Object {if ($_.IsLHR) {"0"} else {"off"}}) -join ','})"
                                    Threads   = if ($Miner_Vendor -eq "CPU") {$CPUThreads} else {$null}
                                }

                                if ($ZilWallet) {
                                    $Arguments.Algorithms += $ZilWallet
                                }

                                [PSCustomObject]@{
                                    Name            = $Miner_Name
                                    DeviceName      = $Miner_Device.Name
                                    DeviceModel     = $Miner_Model
                                    Path            = $Path
                                    Arguments       = $Arguments
					                HashRates      = [PSCustomObject]@{
                                                        $MainAlgorithm_Norm   = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                        $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                    }
                                    API             = "Nanominer"
                                    Port            = $Miner_Port
                                    Uri             = $Uri
                                    FaultTolerance  = $_.FaultTolerance
                                    ExtendInterval  = $_.ExtendInterval
                                    Penalty         = 0
					                DevFee         = [PSCustomObject]@{
								                        ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
								                        ($SecondAlgorithm_Norm) = 0
                                                        }
                                    ManualUri       = $ManualUri
                                    MiningAffinity  = if ($Miner_Vendor -eq "CPU") {$CPUAffinity} else {$null}
                                    Version         = $Version
                                    PowerDraw       = 0
                                    BaseName        = $Name
                                    BaseAlgorithm   = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                    Benchmarked     = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                    LogFile         = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                    #ListDevices    = "-d"
                                    ExcludePoolName = $_.ExcludePoolName
                                    DualZIL         = $ZilWallet -ne $null
                                }
                            }
                        }

                    } else {

                        $Arguments = [PSCustomObject]@{
                            Algorithms = @(
                                [PSCustomObject]@{
                                    Algo      = $MainAlgorithm
                                    Coin      = $MainCoin
                                    Host      = $Pools.$MainAlgorithm_Norm.Host
                                    Port      = $Pool_Port
                                    SSL       = $Pools.$MainAlgorithm_Norm.SSL
                                    Wallet    = $Wallet
                                    PaymentId = $PaymentId
                                    Worker    = "{workername:$($Pools.$MainAlgorithm_Norm.Worker)}"
                                    Pass      = $Pools.$MainAlgorithm_Norm.Pass
                                    Email     = $Pools.$MainAlgorithm_Norm.Email
                                }
                            )                            

                            Devices   = if ($Miner_Vendor -ne "CPU") {$Miner_Device.BusId_Type_Mineable_Index} else {$null}
                            Threads   = if ($Miner_Vendor -eq "CPU") {$CPUThreads} else {$null}
                            LHR       = "$(if ($Miner_Vendor -eq "NVIDIA" -and $MainAlgorithm_Norm -match "^Etc?hash") {($Miner_Device | Foreach-Object {if ($_.IsLHR) {"0"} else {"off"}}) -join ','})"
                        }

                        if ($ZilWallet) {
                            $Arguments.Algorithms += $ZilWallet
                        }

                        [PSCustomObject]@{
                            Name            = $Miner_Name
                            DeviceName      = $Miner_Device.Name
                            DeviceModel     = $Miner_Model
                            Path            = $Path
                            Arguments       = $Arguments
                            HashRates       = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
                            API             = "Nanominer"
                            Port            = $Miner_Port
                            Uri             = $Uri
                            FaultTolerance  = $_.FaultTolerance
                            ExtendInterval  = $_.ExtendInterval
                            Penalty         = 0
                            DevFee          = $_.DevFee
                            ManualUri       = $ManualUri
                            MiningAffinity  = if ($Miner_Vendor -eq "CPU") {$CPUAffinity} else {$null}
                            Version         = $Version
                            PowerDraw       = 0
                            BaseName        = $Name
                            BaseAlgorithm   = $MainAlgorithm_Norm_0
                            Benchmarked     = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile         = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            #ListDevices    = "-d"
                            ExcludePoolName = $_.ExcludePoolName
                            DualZIL         = $ZilWallet -ne $null
                        }
                    }
                }
            }
        })
    }
}
