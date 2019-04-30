using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha){'ryzen'}elseif($f.avx2){'avx2'}elseif($f.avx){'avx'}elseif($f.aes){'aes'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.5-rplant/cpuminer-rplant-4.0.5-linux.tar.gz"
} else {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha){'ryzen'}elseif($f.avx2){'avx2'}elseif($f.avx){'avx'}elseif($f.aes){'aes'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.5-rplant/cpuminer-rplant-4.0.5-win.zip"
}
$ManualUri = "https://pool.rplant.xyz/miners"
$Port = "532{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2ad"; Params = ""; ExtendInterval = 2} #Argon2ad
    [PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""; ExtendInterval = 2} #Argon2d250
    [PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""; ExtendInterval = 2} #Argon2d500
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""; ExtendInterval = 2} #Argon2d4096
    [PSCustomObject]@{MainAlgorithm = "argon2m"; Params = ""; ExtendInterval = 2} #Argon2m
    [PSCustomObject]@{MainAlgorithm = "honeycomb"; Params = ""; ExtendInterval = 2} #Honeycomb
)

if ($IsLinux) {
    $Commands += [PSCustomObject[]]@(
        [PSCustomObject]@{MainAlgorithm = "Binarium_hash_v1"; Params = ""; ExtendInterval = 2} #Binarium
        [PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; ExtendInterval = 2} #Lyra2h
        [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""; ExtendInterval = 2} #Lyra2z330
        [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; ExtendInterval = 2} #ScryptJane16
        [PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""; ExtendInterval = 2} #Verium
        [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""; ExtendInterval = 2} #YescryptR8
        [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""; ExtendInterval = 2} #YescryptR8g
        [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""; ExtendInterval = 2} #YescryptR16
        [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""; ExtendInterval = 2} #YescryptR32
        [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""; ExtendInterval = 2} #Yespower
        [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""; ExtendInterval = 2} #YespowerR16
    )
}

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
				}
			}
		}
    }
}