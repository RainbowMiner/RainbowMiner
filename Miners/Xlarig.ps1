using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://github.com/scala-network/XLArig/releases"
$Port = "241{0:d2}"
$Version = "5.2.2"

if ($IsLinux) {
    $Path = ".\Bin\CPU-Xlarig\xlarig"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.2.2-xlarig/XLArig-v5.2.2-linux-x86_64.zip"
    $DevFee = 0.0
} else {
    $Path = ".\Bin\CPU-Xlarig\xlarig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.2.2-xlarig/XLArig-v5.2.2-win64.zip"
    $DevFee = 0.0
}

if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "panthera"; Params = ""; ExtendInterval = 2}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU.Where({$_.Model -eq $Miner_Model})
    
    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }

                $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                $Arguments = [PSCustomObject]@{
                    Algorithm    = $Algorithm
                    APIParams    = "--http-enabled --http-host=127.0.0.1 --http-port=`$mport"
                    Config = [PSCustomObject]@{
                        "api" = [PSCustomObject]@{
                            "id"           = $null
                            "worker-id"    = $null
                        }
                        "background"   = $false
                        "colors"       = $true
                        "donate-level" = 0
                        "log-file"     = $null
                        "print-time"   = 5
                        "retries"      = 5
                        "retry-pause"  = 1
                    }
                    Pools = @(
                        [PSCustomObject]@{
                            "algo"      = $Algorithm
                            "coin"      = $null
                            "url"       = "$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                            "user"      = $Pools.$Algorithm_Norm.User
                            "pass"      = if ($Pools.$Algorithm_Norm.Pass) {$Pools.$Algorithm_Norm.Pass} else {"x"}
                            "nicehash"  = $Pools.$Algorithm_Norm.Name -match "NiceHash"
                            "keepalive" = $true
                            "enabled"   = $true
                            "tls"       = $Pools.$Algorithm_Norm.SSL
                        }
                    )
                    Params  = $Params
                    HwSig   = "$(($Global:DeviceCache.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"
                    Threads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}  else {$Global:GlobalCPUInfo.Threads}
                    Affinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity} else {$null}
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "XMRig6"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				}
			}
		}
    })
}