﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\CPU-Multi\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'})).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.6.3-cpuminermulti/cpuminer-multi-1.3.6.3.7z"
$ManualUri = "https://github.com/tpruvot/cpuminer-multi/releases"
$Port = "513{0:d2}"
$DevFee = 0.0
$Version = "1.3.6.3"

if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #allium, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""} #axiom
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #BMW
    #[PSCustomObject]@{MainAlgorithm = "drop"; Params = ""} #Drop
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""} #Fresh
    #[PSCustomObject]@{MainAlgorithm = "heavy"; Params = ""} #Heavy
    #[PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #JHA
    #[PSCustomObject]@{MainAlgorithm = "luffa"; Params = ""} #Luffa
    #[PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""} #Pentablake
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    #[PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""} #Pluck
    [PSCustomObject]@{MainAlgorithm = "rfv2"; Params = ""} #Rainforest2
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; Params = ""} #ScryptN
    #[PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""} #SHAvite3
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""} #Skein2
    #[PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""} #ScryptN2, CpuminerVerium faster
    #[PSCustomObject]@{MainAlgorithm = "x12"; Params = ""} #X12
    #[PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #ZR5
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

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU.Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
        $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
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
				}
			}
		}
    })
}