using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-JayDDee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx512) {'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'zen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'} elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'}))"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.10.4-jayddee/cpuminer-opt-3.10.4-linux.7z"
} else {
    $Path = ".\Bin\CPU-JayDDee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx512) {'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'zen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.10.4-jayddee/cpuminer-opt-3.10.4-windows.zip"
}
$ManualUri = "https://github.com/JayDDee/cpuminer-opt/releases"
$Port = "500{0:d2}"
$DevFee = 0.0
$Version = "3.10.4"

if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; NH = $true; Params = ""} #Garlicoin
    [PSCustomObject]@{MainAlgorithm = "anime";  NH = $true; Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "argon2"; NH = $true; Params = ""} #Argon2
    #[PSCustomObject]@{MainAlgorithm = "argon2d-crds"; NH = $true; Params = ""} #Argon2Credits
    #[PSCustomObject]@{MainAlgorithm = "argon2d-dyn";  NH = $true; Params = ""} #Argon2Dynamic
    #[PSCustomObject]@{MainAlgorithm = "argon2d-uis";  NH = $true; Params = ""} #Argon2Unitus
    #[PSCustomObject]@{MainAlgorithm = "axiom"; NH = $true; Params = ""} #axiom
    [PSCustomObject]@{MainAlgorithm = "bastion"; NH = $true; Params = ""} #bastion
    [PSCustomObject]@{MainAlgorithm = "blake2s"; NH = $false; Params = ""} #blake2s
    [PSCustomObject]@{MainAlgorithm = "bmw"; NH = $true; Params = ""} #bmw
    #[PSCustomObject]@{MainAlgorithm = "bmw512"; NH = $true; Params = ""} #bmw512
    #[PSCustomObject]@{MainAlgorithm = "cpupower"; NH = $true; Params = "-N 2048 -R 32 -K `"CPUpower: The number of CPU working or available for proof-of-work mining`""; Algorithm = "yespower"} #CpuPower
    #[PSCustomObject]@{MainAlgorithm = "cryptonightv7"; NH = $true; Params = ""} #CryptoNightV7
    [PSCustomObject]@{MainAlgorithm = "deep"; NH = $true; Params = ""} #deep
    [PSCustomObject]@{MainAlgorithm = "drop"; NH = $true; Params = ""} #drop
    [PSCustomObject]@{MainAlgorithm = "fresh"; NH = $true; Params = ""} #fresh
    [PSCustomObject]@{MainAlgorithm = "heavy"; NH = $true; Params = ""} #heavy
    [PSCustomObject]@{MainAlgorithm = "hex"; NH = $true; Params = ""} #HEX
    [PSCustomObject]@{MainAlgorithm = "hodl"; NH = $true; Params = ""} #HODL
    [PSCustomObject]@{MainAlgorithm = "jha"; NH = $true; Params = ""} #JHA
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; NH = $true; Params = ""} #Lyra2v3
    #[PSCustomObject]@{MainAlgorithm = "lyra2z330"; NH = $true; Params = ""} #lyra2z330, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "m7m"; NH = $true; Params = ""} #m7m, (CpuminerRKZ faster)
    [PSCustomObject]@{MainAlgorithm = "pentablake"; NH = $true; Params = ""} #pentablake
    [PSCustomObject]@{MainAlgorithm = "phi2"; NH = $true; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "pluck"; NH = $true; Params = ""} #pluck
    [PSCustomObject]@{MainAlgorithm = "power2b"; NH = $true; Params = ""} #power2b
    [PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; NH = $true; Params = ""} #Verium
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; NH = $true; Params = ""} #ScryptN
    [PSCustomObject]@{MainAlgorithm = "scrypt:8192"; NH = $true; Params = ""} #Scrypt8k
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; NH = $true; Params = ""} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scryptjane:nf"; NH = $true; Params = ""} #scryptjane:nf
    [PSCustomObject]@{MainAlgorithm = "sha256q"; NH = $true; Params = ""} #sha256q
    [PSCustomObject]@{MainAlgorithm = "shavite3"; NH = $true; Params = ""} #shavite3
    [PSCustomObject]@{MainAlgorithm = "skein2"; NH = $true; Params = ""} #skein2
    [PSCustomObject]@{MainAlgorithm = "sonoa"; NH = $true; Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "veltor"; NH = $true; Params = ""} #Veltor
    [PSCustomObject]@{MainAlgorithm = "x12"; NH = $true; Params = ""} #x12
    [PSCustomObject]@{MainAlgorithm = "x15"; NH = $true; Params = ""} #x15
    #[PSCustomObject]@{MainAlgorithm = "x13bcd"; NH = $true; Params = ""} #bcd
    #[PSCustomObject]@{MainAlgorithm = "x16rt"; NH = $true; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rt
    #[PSCustomObject]@{MainAlgorithm = "x16rt-veil"; NH = $true; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rt-veil
    [PSCustomObject]@{MainAlgorithm = "x16rv2"; NH = $true; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rv2
    [PSCustomObject]@{MainAlgorithm = "x21s"; NH = $true; Params = ""} #x21s
    [PSCustomObject]@{MainAlgorithm = "x22i"; NH = $true; Params = ""} #x22i
    [PSCustomObject]@{MainAlgorithm = "x25x"; NH = $true; Params = ""} #x25x
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; NH = $true; Params = ""} #Yescrypt
    #[PSCustomObject]@{MainAlgorithm = "yescryptr16"; NH = $true; Params = ""} #yescryptr16, CpuminerOptBF faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr32"; NH = $true; Params = ""} #yescryptr32, CpuminerOptBF faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr8"; NH = $true; Params = ""} #yescryptr8, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yespower"; NH = $true; Params = ""} #YesPower
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; NH = $true; Params = ""} #YesPowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "zr5"; NH = $true; Params = ""} #zr5

    #GPU or ASIC - never profitable
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #blake
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blake2b"; Params = ""} #Blake2b, new with v3.9.6.2
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""} #cryptolight
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""} #CryptoNight
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""} #dmd-gr
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""} #Groestl
    #[PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""} #HMQ1725
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""} #keccakc
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2RE2
    #[PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""} #lyra2h
    #[PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""} #lyra2re
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""} #Lyra2z, ZCoin
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #NeoScrypt
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "phi1612"; Params = ""} #phi1612
    #[PSCustomObject]@{MainAlgorithm = "scrypt:N"; Params = ""} #scrypt:N
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""} #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""} #sha256t
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""} #whirlpoolx
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""} #x13
    #[PSCustomObject]@{MainAlgorithm = "x13sm3"; Params = ""} #x13sm3
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #x14
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""} #x16r
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""} #X16s
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #X17
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
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model

    $DeviceParams = "--hash-meter $(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Algorithm_Norm -ne "Lyra2z330" -or $Pools.$Algorithm_Norm.Name -ne "Zpool") -and ($_.NH -or $Pools.$Algorithm_Norm.Name -ne "NiceHash")) {
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
					Arguments      = "-b `$mport -a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) $($_.Params)"
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
    }
}