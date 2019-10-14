using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-Xmrig\xmrig"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.0-xmrig/xmrig-3.2.0-xenial-x64.tar.gz"
    $DevFee = 1.0
} else {
    $Path = ".\Bin\CPU-Xmrig\xmrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.2.0-xmrig/xmrig-3.2.0-msvc-win64-rbm.7z"
    $DevFee = 0.0
}
$ManualUri = "https://github.com/xmrig/xmrig/releases"
$Port = "521{0:d2}"
$Version = "3.2.0"


if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwa"; Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "argon2/wrkz";   Params = ""; ExtendInterval = 2}
    #[PSCustomObject]@{MainAlgorithm = "cn/1";          Params = ""; ExtendInterval = 2}
    #[PSCustomObject]@{MainAlgorithm = "cn/2";          Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/double";     Params = ""; ExtendInterval = 2}
    #[PSCustomObject]@{MainAlgorithm = "cn/gpu";        Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/half";       Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/fast2";      Params = ""; ExtendInterval = 2; Algorithm = "cn/fast"}
    [PSCustomObject]@{MainAlgorithm = "cn/r";          Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/rto";        Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/rwz";        Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/xao";        Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn/zls";        Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/0";    Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/tube"; Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/xhv";  Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn-lite/1";     Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cn-pico";       Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "rx/loki";       Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "rx/0";          Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "rx/wow";        Params = ""; ExtendInterval = 2}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {

                $Arguments = [PSCustomObject]@{
                    Algorithm    = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                    PoolParams   = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
                    APIParams    = "--http-enabled --http-host=127.0.0.1 --http-port=$($Miner_Port)"
                    Config = [PSCustomObject]@{
                        "api" = [PSCustomObject]@{
                            "id"           = $null
                            "worker-id"    = $null
                        }
                        "background"   = $false
                        "colors"       = $true
                        "donate-level" = if ($IsLinux) {1} else {0}
                        "log-file"     = $null
                        "print-time"   = 5
                        "retries"      = 5
                        "retry-pause"  = 1
                    }
                    Params  = $Params
                    HwSig   = "$(($Session.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"
                    Threads = if ($Session.Config.CPUMiningThreads){$Session.Config.CPUMiningThreads} else {$Global:GlobalCPUInfo.Threads}
                    Affinity= if ($Session.Config.CPUMiningAffinity -ne '') {$Session.Config.CPUMiningAffinity} else {$null}
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
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
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}