using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.INTEL -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No devices present in system

# this miner module is currently disabled.
# return

$ManualUri = "https://github.com/bzminer/bzminer/releases"
$Port = "332{0:d2}"
$DevFee = 0.5
$Cuda = "11.2"
$Version = "100.10"

if ($IsLinux) {
    $Path = ".\Bin\GPU-BzMiner\bzminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v100.10-bzminer/bzminer_v100.10_linux.tar.gz"
} else {
    $Path = ".\Bin\GPU-BzMiner\bzminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v100.10-bzminer/bzminer_v100.10_windows.zip"
}

$ExcludePoolName = "prohashing|miningrigrentals"

# v100.10 is a complete rewrite: dual mining and most of the v24 algorithms are gone,
# the remaining ones are exactly what "bzminer --list-algos" reports for this build.
$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ergo";    DAG = $true; MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #Autolykos2/ERG
    [PSCustomObject]@{MainAlgorithm = "etchash"; DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; Fee = 0.5} #Etchash/ETC
    [PSCustomObject]@{MainAlgorithm = "ethash";  DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","NVIDIA");         ExtendInterval = 2; Fee = 0.5} #Ethash/ETHW
    [PSCustomObject]@{MainAlgorithm = "kawpow";  DAG = $true; MinMemGb = 3; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #KawPow
    [PSCustomObject]@{MainAlgorithm = "pearl";                MinMemGb = 2; Params = ""; Vendor = @("AMD","CPU","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #PearlHash/PRL
    [PSCustomObject]@{MainAlgorithm = "randomx";              MinMemGb = 2; Params = ""; Vendor = @("CPU");                  ExtendInterval = 2; Fee = 1.0} #RandomX/XMR
    [PSCustomObject]@{MainAlgorithm = "verus";                MinMemGb = 1; Params = ""; Vendor = @("CPU");                  ExtendInterval = 2; Fee = 1.0} #VerusHash/VRSC
    [PSCustomObject]@{MainAlgorithm = "warthog";              MinMemGb = 2; Params = ""; Vendor = @("AMD","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 2.0; WithCPU = $true; NoCPUMining = $true} #JanusHash/WART, needs GPU and CPU together
    [PSCustomObject]@{MainAlgorithm = "xelis";                MinMemGb = 2; Params = ""; Vendor = @("AMD","CPU","INTEL","NVIDIA"); ExtendInterval = 2; Fee = 1.0} #XelisHashV3/XEL
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

$CommonParams =  "--config config_`$mport.txt --http_address 127.0.0.1 --http_port `$mport --no-watchdog --output log --no-color --logfile bzminer_`$mport.log --logfile-mode overwrite"

foreach ($Miner_Vendor in @("AMD","CPU","INTEL","NVIDIA")) {

    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model}

        if (-not $Device -or ($Miner_Vendor -eq "NVIDIA" -and $Miner_Model -match "-" -and ($Device | Where-Object {$_.IsLHR} | Measure-Object).Count -gt 0)) {return}

        $Device_BusId = @($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq $Miner_Vendor} | Select-Object -ExpandProperty BusId -Unique)

        # a device type flag given a value only sets that type, everything left out stays enabled by default
        $VendorParams = Switch ($Miner_Vendor) {
            "AMD" {"--amd 1 --intel 0 --nvidia 0"}
            "CPU" {"--amd 0 --intel 0 --nvidia 0 --cpu 1"}
            "INTEL" {"--amd 0 --intel 1 --nvidia 0"}
            "NVIDIA" {"--amd 0 --intel 0 --nvidia 1"}
        }

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and (-not $_.Version -or [version]$_.Version -le [version]$Version)} | ForEach-Object {
            $First = $true

            $MainAlgorithm_0  = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $MainAlgorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $CPUParams = if ($Miner_Vendor -ne "CPU") {" --cpu $(if ($_.WithCPU) {"1"} else {"0"})"}

            $AffinityParams = if ($Miner_Vendor -eq "CPU") {
                $CPUAffinity = if ($Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$MainAlgorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
                if ($CPUAffinity) {"--cpu_affinity $((ConvertFrom-CPUAffinity $CPUAffinity) -join ",") "}
            }

            foreach($MainAlgorithm_Norm in @(Get-PoolAlgorithmKeys -Pools $Pools -Algorithm $MainAlgorithm_Norm_0 -Model $Miner_Model -ExcludePoolName $ExcludePoolName)) {
                if (-not $Pools.$MainAlgorithm_Norm.Host) {continue}

                if ($Miner_Vendor -ne "CPU") {
                    $MinMemGB = if ($_.DAG) {if ($Pools.$MainAlgorithm_Norm.DagSizeMax) {$Pools.$MainAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
                    $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
                    $DisableDevices = @(Compare-Object $Device_BusId @($Miner_Device | Select-Object -ExpandProperty BusId -Unique) | Where-Object {$_.SideIndicator -eq "<="} | Foreach-Object {"!$(($_.InputObject -split ':' | Foreach-Object {[uint32]"0x$_"}) -join ':')"}) -join ','
                } else {
                    $Miner_Device = $Device
                    $DisableDevices = $null
                }

                if ($Miner_Device -and (-not $ExcludePoolName -or $Pools.$MainAlgorithm_Norm.Host -notmatch $ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$MainAlgorithm_Norm.CoinSymbol) -and ($Pools.$MainAlgorithm_Norm.User -notmatch "@")) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }

                    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}
                    $Pool_Protocol = Switch($Pools.$MainAlgorithm_Norm.EthMode) {
                                        "ethproxy"      {"ethproxy+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum1"   {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"ethstratum+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum2"   {"ethstratum2+$(if ($Pools.$MainAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        default         {$Pools.$MainAlgorithm_Norm.Protocol}
                                     }

                    [PSCustomObject]@{
                        Name            = $Miner_Name
                        DeviceName      = $Miner_Device.Name
                        DeviceModel     = $Miner_Model
                        Path            = $Path
                        Arguments       = "-a $($MainAlgorithm_0) $($VendorParams)$($CPUParams)$(if ($DisableDevices) {" --devices $($DisableDevices)"}) -p $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host)$(if ($Pool_Port -and $Pools.$MainAlgorithm_Norm.Host -notmatch "/") {":$($Pool_Port)"}) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" --pass $($Pools.$MainAlgorithm_Norm.Pass)"})$(if ($Pools.$MainAlgorithm_Norm.Worker) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) $($AffinityParams)$($CommonParams) $($_.Params)"
                        HashRates       = [PSCustomObject]@{$MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))}
                        API             = "BzMiner"
                        Port            = $Miner_Port
                        FaultTolerance  = $_.FaultTolerance
                        ExtendInterval  = $_.ExtendInterval
                        Penalty         = 0
                        DevFee          = if ($_.Fee -ne $null) {$_.Fee} else {$DevFee}
                        Uri             = $Uri
                        ManualUri       = $ManualUri
                        NoCPUMining     = $_.NoCPUMining
                        Version         = $Version
                        PowerDraw       = 0
                        BaseName        = $Name
                        BaseAlgorithm   = $MainAlgorithm_Norm_0
                        Benchmarked     = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                        LogFile         = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                        ExcludePoolName = $ExcludePoolName
                        MultiProcess    = 1
                    }
                }
            }
        }
    }
}
