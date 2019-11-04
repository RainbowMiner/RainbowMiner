using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.aes){'aes'}elseif($f.sse42){'sse42'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.22-rplant/cpuminer-rplant-4.0.22-linux.7z"
} else {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.aes){'aes'}elseif($f.sse42){'sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0.22-rplant/cpuminer-rplant-4.0.22-win.zip"
}
$ManualUri = "https://github.com/rplant8/cpuminer-opt-rplant/releases"
$Port = "532{0:d2}"
$DevFee = 0.0
$Version = "4.0.22"

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2ad"; Params = ""} #Argon2ad (URX)
    [PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""} #Argon2d500 (DYN)
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""} #Argon2d4096 (UIS)
    [PSCustomObject]@{MainAlgorithm = "argon2d-glt"; GLT="argon2d-glt"; Params = ""} #Argon2d (GLT)
    [PSCustomObject]@{MainAlgorithm = "argon2i-glt"; GLT="argon2i-glt"; Params = ""} #Argon2i (GLT)
    [PSCustomObject]@{MainAlgorithm = "argon2m"; Params = ""} #Argon2m (Merge)
	[PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""; LinuxOnly = $true} #CpuPower
    [PSCustomObject]@{MainAlgorithm = "cryptovantaa"; Params = ""} #IOtE
    #[PSCustomObject]@{MainAlgorithm = "honeycomb"; Params = ""} #Honeycomb
    [PSCustomObject]@{MainAlgorithm = "lyra2cz"; Params = ""} #Lyra2cz
	[PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; LinuxOnly = $true} #Lyra2h
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""} #Lyra2z330
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = ""; MaxRejectedShareRatio = 0.7} #Yespower2b
	[PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""; LinuxOnly = $true} #Verium
	[PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; LinuxOnly = $true} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr16v2"; GLT="yescryptr16v2glt"; Params = ""} #YescryptR16v2
    [PSCustomObject]@{MainAlgorithm = "yescryptr24"; GLT="yescryptr24glt"; Params = ""} #YescryptR24
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; GLT="yescryptr32glt"; Params = ""} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; GLT="yescryptr8glt"; Params = ""} #YescryptR8
    [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""} #YescryptR8g (KOTO)
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""; LinuxOnly = $true} #Yespower
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16
    [PSCustomObject]@{MainAlgorithm = "yespowerIC"; Params = ""} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerLITB"; Params = ""} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerLTNCG"; Params = ""} #Yespower LighningCash-Gold v3 (LTNCG)
    [PSCustomObject]@{MainAlgorithm = "yespowerRES"; Params = ""} #Yespower Resistance (RES)
    [PSCustomObject]@{MainAlgorithm = "yespowerSUGAR"; Params = ""} #Yespower SugarChain (SUGAR)
    [PSCustomObject]@{MainAlgorithm = "yespowerURX"; Params = ""} #Yespower Uranium-X (URX)
    [PSCustomObject]@{MainAlgorithm = "Binarium_hash_v1"; Params = ""} #Binarium
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
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | Where-Object {-not $_.LinuxOnly -or $IsLinux} | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Algorithm_Norm -ne "Lyra2z330" -or $Pools.$Algorithm_Norm.Name -ne "Zpool")) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }
                $Miner_Coin = $Pools.$Algorithm_Norm.CoinSymbol
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-b `$mport -a $(if ($Miner_Coin -and $_.$Miner_Coin) {$_.$Miner_Coin} else {$_.MainAlgorithm}) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
                    Penalty        = 0
                    MaxRejectedShareRatio = $_.MaxRejectedShareRatio
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