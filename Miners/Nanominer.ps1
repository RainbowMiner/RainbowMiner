﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualURI = "https://github.com/nanopool/nanominer/releases"
$Port = "534{0:d2}"
$Cuda = "10.0"
$DevFee = 3.0
$Version = "3.2.2"

if ($IsLinux) {
    $Path = ".\Bin\ANY-Nanominer\nanominer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.2-nanominer/nanominer-linux-3.2.2-cuda11.tar.gz"
            Cuda = "11.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.2-nanominer/nanominer-linux-3.2.2.tar.gz"
            Cuda = "10.0"
        }
    )
} else {
    $Path = ".\Bin\ANY-Nanominer\nanominer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.2-nanominer/nanominer-windows-3.2.2-cuda11.zip"
            Cuda = "11.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.2-nanominer/nanominer-windows-3.2.2.zip"
            Cuda = "10.0"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos";               Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DevFee = 5.0} #Autolycos/Ergo
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo30";              Params = ""; MinMemGb = 14; Vendor = @("AMD");          ExtendInterval = 2; DevFee = 5.0} #Cuckaroo30/Cortex
    [PSCustomObject]@{MainAlgorithm = "Ethash";     DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD");          ExtendInterval = 2; DevFee = 1.0; ExcludePoolName = "^F2Pool"} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EtcHash";    DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD");          ExtendInterval = 2; DevFee = 1.0} #EtcHash
    [PSCustomObject]@{MainAlgorithm = "KawPow";     DAG = $true; Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DevFee = 2.0} #KawPOW
    #[PSCustomObject]@{MainAlgorithm = "Octopus";    DAG = $true; Params = ""; MinMemGb = 5;  Vendor = @("NVIDIA");       ExtendInterval = 2; DevFee = 2.0} #Octopus/Conflux
    [PSCustomObject]@{MainAlgorithm = "RandomHash2";             Params = ""; MinMemGb = 3;  Vendor = @("CPU");          ExtendInterval = 2; DevFee = 0.0} #RandomHash2/PASCcoin, RHminerCpu is more than 350% faster
    [PSCustomObject]@{MainAlgorithm = "RandomX";                 Params = ""; MinMemGb = 3;  Vendor = @("CPU");          ExtendInterval = 2; DevFee = 2.0} #RandomX
    [PSCustomObject]@{MainAlgorithm = "Verushash";               Params = ""; MinMemGb = 3;  Vendor = @("CPU");          ExtendInterval = 2; DevFee = 2.0; CPUFeatures = @("avx","aes")} #Verushash
    [PSCustomObject]@{MainAlgorithm = "UbqHash";                 Params = ""; MinMemGb = 3;  Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; DevFee = 1.0; Algorithm = "Ethash"; Coins = @("UBQ"); ExcludePoolName = "^F2Pool"} #UbqHash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
        }
    }
}

if (-not $Cuda) {
    $Uri = $UriCuda[0].Uri
}

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and (-not $_.CPUFeatures -or ($Global:GlobalCPUInfo.Features -and -not (Compare-Object @($Global:GlobalCPUInfo.Features.Keys) $_.CPUFeatures | Where-Object SideIndicator -eq "=>" | Measure-Object).Count))}).ForEach({
            $First = $true
            $Algorithm_Norm_0 = if ($_.Algorithm) {Get-Algorithm $_.Algorithm} else {Get-Algorithm $_.MainAlgorithm}

            if ($Miner_Vendor -eq "CPU") {
                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
            }

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or (($Algorithm_Norm_0 -ne "Cuckaroo30" -or $_.Model -eq "RX57016GB") -and (Test-VRAM $_ $MinMemGb))}

            $All_Algorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

		    foreach($Algorithm_Norm in $All_Algorithms) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName) -and (-not $_.Coins -or ($Pools.$Algorithm_Norm.CoinSymbol -and $_.Coins -icontains $Pools.$Algorithm_Norm.CoinSymbol))) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }
					$Pool_Port = if ($Miner_Vendor -ne "CPU" -and $Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                    $Wallet    = if ($Pools.$Algorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User}
                    $PaymentId = $null
                    if ($Algorithm_Norm -match "^RandomHash" -or $Algorithm_Norm -match "^Cryptonight") {
                        if ($Wallet -match "^(.+?)[\.\+]([0-9a-f]{16,})") {
                            $Wallet    = $Matches[1]
                            $PaymentId = $Matches[2]
                        } elseif ($Algorithm_Norm -match "^RandomHash") {
                            $PaymentId = "0"
                        }
                    }

				    $Arguments = [PSCustomObject]@{
                        Algo      = $_.MainAlgorithm
                        Coin      = $Pools.$Algorithm_Norm.CoinSymbol
					    Host      = $Pools.$Algorithm_Norm.Host
					    Port      = $Pools.$Algorithm_Norm.Port
					    SSL       = $Pools.$Algorithm_Norm.SSL
					    Wallet    = $Wallet
                        PaymentId = $PaymentId
                        Worker    = "{workername:$($Pools.$Algorithm_Norm.Worker)}"
                        Pass      = $Pools.$Algorithm_Norm.Pass
                        Email     = $Pools.$Algorithm_Norm.Email
                        Threads   = if ($Miner_Vendor -eq "CPU") {$CPUThreads} else {$null}
                        Devices   = if ($Miner_Vendor -ne "CPU") {$Miner_Device.BusId_Mineable_Index} else {$null}
				    }

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = $Arguments
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "Nanominer"
					    Port           = $Miner_Port
					    Uri            = $Uri
					    FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = $_.DevFee
					    ManualUri      = $ManualUri
                        MiningAffinity = if ($Miner_Vendor -eq "CPU") {$CPUAffinity} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
				    }
			    }
		    }
        })
    }
}