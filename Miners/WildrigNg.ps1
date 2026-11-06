using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) -and $Global:GlobalCPUInfo.Architecture -ne 8) {return} # Linux ARM: aarch64 build only
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://github.com/andru-kun/wildrig-ng"
$Port = "421{0:d2}"
$DevFee = 0.00
$Cuda = "11.0"
$Version = "1.0.0u"

if ($IsLinux) {
    $Path = ".\Bin\GPU-WildrigNg\wildrig-ng"
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0u-wildrigng/wildrig-ng-linux-aarch64-1.0.0u.tar.gz"
    } else {
        $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0u-wildrigng/wildrig-ng-linux-1.0.0u.tar.gz"
    }
} else {
    $Path = ".\Bin\GPU-WildrigNg\wildrig-ng.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0u-wildrigng/wildrig-ng-windows-1.0.0u.zip"
}

# wildrig-ng is the successor of wildrig-multi (Miners\WildRig.ps1): CUDA + OpenCL,
# NVIDIA Pascal and newer, AMD Polaris (GCN4) and newer (GCN2/GCN3 for kawpow and
# progpowz only, CDNA on Linux/ROCm), Intel Arc. The fees are the ones the miner
# prints with --help.
$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos2";  DAG = $true; MinMemGb = 2; Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 0.00; ExcludeAmdCapability = "GCN[123]"} #Autolykos2/ERG
    [PSCustomObject]@{MainAlgorithm = "kawpow";      DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "unMineable"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";    DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";    DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";    DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";    DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "unMineable"; Algorithm = "kawpow"} #KawPOW
    [PSCustomObject]@{MainAlgorithm = "nexapow";     DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludeAmdCapability = "GCN[123]"; ExcludeNvCompute = "Pascal"} #NexaPow/NEXA - 1.0.0u never finishes the window table on Pascal (GTX1070: "blocked in the driver", watchdog restarts), Ampere works
    [PSCustomObject]@{MainAlgorithm = "octopus";     DAG = $true; MinMemGb = 4; Vendor = @("NVIDIA");               Params = ""; ExtendInterval = 3; DevFee = 0.00} #Octopus/CFX
    [PSCustomObject]@{MainAlgorithm = "pearlhash";                              Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 0.00; ExcludePoolName = "BaikalMine|F2pool|HeroMiners|K1Pool|K1PoolSolo|Kryptex|KryptexSolo|LuckyPool|Mining4people|RPlant|RPlantSolo|SuprNova|unMineable"; AmdCompute = "RDNA"} #Pearlhash/PRL, NVIDIA Pascal+ (except Tesla P100), AMD RDNA1-4, Intel Arc
    [PSCustomObject]@{MainAlgorithm = "poseidon2b";                             Vendor = @("AMD","NVIDIA");         Params = ""; ExtendInterval = 2; DevFee = 2.00; Algorithm = "noid"; AmdCompute = "RDNA"; ExcludeNvCompute = "Pascal"} #Noid/NOID, NVIDIA Volta+, AMD RDNA1-4
    [PSCustomObject]@{MainAlgorithm = "progpowz";    DAG = $true;               Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludePoolName = "Fairpool"} #ProgPowZ/ZANO
    [PSCustomObject]@{MainAlgorithm = "qhash";                                  Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 2.00; FaultTolerance = 0.4; ExcludeAmdCapability = "GCN[123]"} #Qhash/QTC
    [PSCustomObject]@{MainAlgorithm = "quantus";                                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 2; DevFee = 2.00; ExcludeAmdCapability = "GCN[123]"} #Quantus/QUAN
    [PSCustomObject]@{MainAlgorithm = "sha256d";                                Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; DevFee = 0.00; ExcludeAmdCapability = "GCN[123]"; NeverProfitable = $true} #SHA256d/BTC
    [PSCustomObject]@{MainAlgorithm = "xelishashv3";                            Vendor = @("AMD","INTEL","NVIDIA"); Params = ""; ExtendInterval = 3; DevFee = 1.00; ExcludeAmdCapability = "GCN[123]"; ExcludePoolName = "unMineable"} #XelisHashV3/XEL - unMineable labels its jobs "xel/3", 1.0.0u only accepts "xel/v3" and ignores every job
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","INTEL","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","INTEL","NVIDIA")) {

    # --gpu-list takes the miner's own GPU numbers: the GPUs it enumerates, in PCI bus
    # order. The other vendors are switched off per instance, so the numbers are the
    # vendor-local bus order of every card of that vendor, selected or not - that is
    # DeviceLib's BusId_Type_Vendor_Index. Integrated GPUs are skipped by the miner (no
    # --gpu-allow-igpu), so Intel bus 00 iGPUs are left out and the cards behind them
    # move up by their count (the bus 00 rule of BusId_Type_Mineable_Index).
    $DeviceIndex = @{}
    $iGPUs = 0
    if ($Miner_Vendor -eq "INTEL") {
        $iGPUs = @($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "INTEL" -and $_.BusId -match "^00:"}).Count
    }
    foreach ($Dev in @($Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Type -eq "GPU" -and ($_.Vendor -ne "INTEL" -or $_.BusId -notmatch "^00:")})) {
        $DeviceIndex[$Dev.Name] = [int]$Dev.BusId_Type_Vendor_Index - $iGPUs
    }

    $DeviceParams = Switch ($Miner_Vendor) {
        "AMD"    {"--gpu-no-intel --gpu-no-nvidia"}
        "INTEL"  {"--gpu-no-amd --gpu-no-nvidia"}
        "NVIDIA" {"--gpu-no-amd --gpu-no-intel"}
    }

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model -and $DeviceIndex.ContainsKey($_.Name)}

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.NeverProfitable -or $Session.Config.EnableNeverprofitableAlgos) -and (-not $_.Version -or (Compare-Version $Version $_.Version) -ge 0)} | ForEach-Object {
            $First = $True

            $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $All_Algorithms = @(Get-PoolAlgorithmKeys -Pools $Pools -Algorithm $Algorithm_Norm_0 -Model $Miner_Model -ExcludePoolName "$($_.ExcludePoolName)" -CoinSymbols @($_.CoinSymbols))

            foreach($Algorithm_Norm in $All_Algorithms) {
                if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $Worker = ""

                $MinMemGB = if ($_.DAG) {if ($Pools.$Algorithm_Norm.DagSizeMax) {$Pools.$Algorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
                if ($Miner_Vendor -eq "AMD" -and $_.AmdCompute) {
                    $AmdCompute = $_.AmdCompute
                    $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -match $AmdCompute}
                }
                if ($Miner_Vendor -eq "NVIDIA") {
                    if ($_.NvCompute) {
                        $NvCompute = $_.NvCompute
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.Architecture -match $NvCompute}
                    }
                    if ($_.ExcludeNvCompute) {
                        $NvCompute = $_.ExcludeNvCompute
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.Architecture -notmatch $NvCompute}
                    }
                } elseif ($Miner_Vendor -eq "AMD") {
                    if ($_.AmdCapability) {
                        $AmdCapability = @($_.AmdCapability) -join "|"
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -match $AmdCapability}
                    }
                    if ($_.ExcludeAmdCapability) {
                        $AmdCapability = $_.ExcludeAmdCapability
                        $Miner_Device = $Miner_Device | Where-Object {$_.OpenCL.DeviceCapability -notmatch $AmdCapability}
                    }
                }

                if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = ($Miner_Device | ForEach-Object {$DeviceIndex[$_.Name]} | Sort-Object) -join ','
                        $First = $false
                    }

                    # the miner sends user.worker itself, so --worker is only added when the pool's login is the bare wallet
                    if ($Pools.$Algorithm_Norm.Worker -and $Pools.$Algorithm_Norm.Password -eq "x" -and $Pools.$Algorithm_Norm.User -eq $Pools.$Algorithm_Norm.Wallet) {
                        $Worker = " --worker $($Pools.$Algorithm_Norm.Worker)"
                    }

                    $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                    [PSCustomObject]@{
                        Name           = $Miner_Name
                        DeviceName     = $Miner_Device.Name
                        DeviceModel    = $Miner_Model
                        Path           = $Path
                        Arguments      = "--api-port `$mport -a $($Algorithm) -o stratum+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User -replace "^nexa:")$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Worker) --pool-retries 4 --pool-retry-pause 5 --pool-max-rejects 10 --gpu-list $($DeviceIDsAll) $($DeviceParams) --gpu-temp-limit 95 --ui-plain --no-watchdog $($_.Params)"
                        HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                        API            = "Xmrig"
                        Port           = $Miner_Port
                        Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
                        ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
                        DevFee         = if ($_.DevFee) {$_.DevFee} else {$DevFee}
                        ManualUri      = $ManualUri
                        EnvVars        = @("GPU_MAX_WORKGROUP_SIZE=256")
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        ExcludePoolName = $_.ExcludePoolName
                    }
                }
            }
        }
    }
}
