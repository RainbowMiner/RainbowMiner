using module ..\Include.psm1

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

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""; ExtendInterval = 2} #Argon2d-crds
    #[PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""; ExtendInterval = 2} #Argon2d-dyn
    #[PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""; ExtendInterval = 2} #Argon2d-uis
    [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""; ExtendInterval = 2} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""; ExtendInterval = 2} #m7m (fastest)
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""; ExtendInterval = 2} #Yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""; ExtendInterval = 2} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""; ExtendInterval = 2} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""; ExtendInterval = 2} #YescryptR8
    #[PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""; ExtendInterval = 2} #Yespower (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerlitb"; Params = ""; ExtendInterval = 2} #YespowerLITB
    #[PSCustomObject]@{MainAlgorithm = "yespowerltncg"; Params = ""; ExtendInterval = 2} #YespowerLTNCG
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""; ExtendInterval = 2} #YespowerR16-ynt (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = ""; ExtendInterval = 2} #YespowerURX
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

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				[PSCustomObject]@{
					Name = $Miner_Name
					DeviceName = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path = $Path
					Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) $($_.Params)"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API = "Ccminer"
					Port = $Miner_Port
					Uri = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					DevFee = $DevFee
					ManualUri = $ManualUri
                    Version   = $Version
				}
			}
		}
    }
}