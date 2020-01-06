﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-Xlarig\xlarig"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.1-xlarig/XLArig-v5.0.1-linux-x86_64.zip"
    $DevFee = 0.0
} else {
    $Path = ".\Bin\CPU-Xlarig\xlarig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.1-xlarig/XLArig-v5.0.1-win64.zip"
    $DevFee = 0.0
}
$ManualUri = "https://github.com/scala-network/XLArig/releases"
$Port = "541{0:d2}"
$Version = "5.0.1"


if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "defyx"; Params = ""; ExtendInterval = 2}
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
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model
    
    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }

                $Arguments = [PSCustomObject]@{
                    Algorithm    = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                    PoolParams   = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
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
                    Params  = $Params
                    HwSig   = "$(($Global:DeviceCache.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"
                    Threads = if ($Session.Config.CPUMiningThreads){$Session.Config.CPUMiningThreads} else {$Global:GlobalCPUInfo.Threads}
                    Affinity= if ($Session.Config.CPUMiningAffinity -ne '') {$Session.Config.CPUMiningAffinity} else {$null}
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "XMRig3"
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
				}
			}
		}
    }
}