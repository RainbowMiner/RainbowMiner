using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Path = ".\Bin\CPU-ArcticHash\cpuminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.7.1-cpuminerarctichash/cpuminer-arctichash-v1.3.7.1.7z"
$ManualUri = ""
$Port = "245{0:d2}"
$DevFee = 0.0
$Version = "1.3.7.1"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "arctichash"; Params = ""} #Arctichash
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU | Where-Object {$_.Model -eq $Miner_Model}

    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
        $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if (-not $Pools.$Algorithm_Norm.SSL -and $Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }
			    [PSCustomObject]@{
				    Name           = $Miner_Name
				    DeviceName     = $Miner_Device.Name
				    DeviceModel    = $Miner_Model
				    Path           = $Path
				    Arguments      = "-b `$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)"
				    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
				    API            = "Ccminer"
				    Port           = $Miner_Port
				    Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
				    ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
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
    }
}
