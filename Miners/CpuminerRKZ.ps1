﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-rkz\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.sse2 -and $f.aes){'aes-sse2'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.9.7c-cpuminerrkz/cpuminer-RKZ-3.9.7c-ubuntu18.7z"
} else {
    $Path = ".\Bin\CPU-rkz\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'sha-avx2'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.9.7c-cpuminerrkz/cpuminer-RKZ-3.9.7c-win64.7z"
}
$ManualUri = "https://github.com/patrykwnosuch/cpuminer-RKZ/releases"
$Port = "542{0:d2}"
$DevFee = 0.0
$Version = "3.9.7c"

if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""} #Argon2d-crds
    #[PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""} #Argon2d-dyn
    #[PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""} #Argon2d-uis
    [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""} #m7m (fastest)
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8
    #[PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerlitb"; Params = ""} #YespowerLITB
    #[PSCustomObject]@{MainAlgorithm = "yespowerltncg"; Params = ""} #YespowerLTNCG
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16-ynt (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = ""} #YespowerURX
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