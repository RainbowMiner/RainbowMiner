using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$ManualUri = "https://github.com/Kudaraidee/cpuminer-opt-kudaraidee/releases"
$Port = "212{0:d2}"
$DevFee = 0.0
$Version = "1.2.3"

if ($IsLinux) {
    $Path = ".\Bin\CPU-Kudaraidee\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx512 -and $f.sha -and $f.vaes){'avx512-sha-vaes'}elseif($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.avx){'avx'}elseif($f.sse42 -and $f.aes){'sse42-aes'}elseif($f.sse42){'sse42'}elseif($Global:GlobalCPUInfo.Vendor -eq "AMD"){'sse2amd'}else{'sse2'}))"
    $URI = "https://github.com/Kudaraidee/cpuminer-opt-kudaraidee/releases/download/v1.2.3/cpuminer-opt-kudaraidee-1.2.3_linux.tar.gz"
} else {
    $Path = ".\Bin\CPU-Kudaraidee\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.avx){'avx'}elseif($f.sse42 -and $f.aes){'sse42-aes'}elseif($f.sse42){'sse42'}elseif($Global:GlobalCPUInfo.Vendor -eq "AMD"){'sse2amd'}else{'sse2'})).exe"
    $Uri = "https://github.com/Kudaraidee/cpuminer-opt-kudaraidee/releases/download/v1.2.3/cpuminer-opt-kudaraidee-1.2.3_windows.zip"
    $Version = "1.2.3"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #Garlicoin
    [PSCustomObject]@{MainAlgorithm = "anime";  Params = ""} #Anime
    [PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""} #Argon2Credits (argon2d-crds)
    [PSCustomObject]@{MainAlgorithm = "argon2d500";  Params = ""} #Argon2Dynamic (argon2d-dyn)
    [PSCustomObject]@{MainAlgorithm = "argon2d1000";  Params = ""} 
    [PSCustomObject]@{MainAlgorithm = "argon2d4096";  Params = ""} #Argon2Unitus (argon2d-uis)
    [PSCustomObject]@{MainAlgorithm = "argon2d16000";  Params = ""} 
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #bmw
    [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""} #CpuPower
    [PSCustomObject]@{MainAlgorithm = "flex"; Params = ""} #Flex
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #JHA
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; Params = ""} #Lyra2v3
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""} #lyra2z330, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""} #m7m, (CpuminerRKZ faster)
    [PSCustomObject]@{MainAlgorithm = "minotaur"; Params = ""} #Minotaur/RNG
    [PSCustomObject]@{MainAlgorithm = "minotaurx"; Params = ""} #MinotaurX/AVN
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = ""} #power2b
    [PSCustomObject]@{MainAlgorithm = "rinhash"; Params = ""} #Rincoin
    [PSCustomObject]@{MainAlgorithm = "scryptn2"} #ScryptN2
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; Params = ""} #ScryptN11, CpuminerMulti faster
    [PSCustomObject]@{MainAlgorithm = "scrypt:8192"; Params = ""} #Scrypt8k
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scryptjane:nf"; Params = ""} #scryptjane:nf
    [PSCustomObject]@{MainAlgorithm = "sha256dt"; Params = ""} #sha256dt
    [PSCustomObject]@{MainAlgorithm = "sha256q"; Params = ""} #sha256q
    [PSCustomObject]@{MainAlgorithm = "sha512256d"; Params = ""} #sha512256d
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel (MAC) Machinecoin
    [PSCustomObject]@{MainAlgorithm = "verthash"; Params = ""} #VertHash
    [PSCustomObject]@{MainAlgorithm = "x12"; Params = ""} #x12
    [PSCustomObject]@{MainAlgorithm = "xelishashv2_pepew"; Params = ""} #Pepepow
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #yescryptr16, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #yescryptr32, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #yescryptr8, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""} #yescryptr8g, KOTO
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #YesPower
    [PSCustomObject]@{MainAlgorithm = "yespowerADVC"; Params = ""} #AdventureCoin
    [PSCustomObject]@{MainAlgorithm = "yespowerARWN"; Params = ""} #Arrowana
    [PSCustomObject]@{MainAlgorithm = "yespowerIC"; Params = "--param-n 2048 --param-r 32 --param-key `"IsotopeC`""; Algorithm = "yespower"} #Yespower IsotopeC (IC)
    [PSCustomObject]@{MainAlgorithm = "yespowerIOTS"; Params = "--param-n 2048 --param-key `"Iots is committed to the development of IOT`""; Algorithm = "yespower"} #Yespower .. (IOTS)
    [PSCustomObject]@{MainAlgorithm = "yespowerLITB"; Params = "--param-n 2048 --param-r 32 --param-key `"LITBpower: The number of LITB working or available for proof-of-work mini`""; Algorithm = "yespower"} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerLTNCG"; Params = "--param-n 2048 --param-r 32 --param-key `"LTNCGYES`""; Algorithm = "yespower"} #Yespower LighningCash-Gold v3 (LTNCG)
    [PSCustomObject]@{MainAlgorithm = "yespowerMGPC"; Params = ""} #Magpiecoin
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YesPowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "yespowerSUGAR"; Params = ""} #Yespower SugarChain (SUGAR)
    [PSCustomObject]@{MainAlgorithm = "yespowerTIDE"; Params = "--param-n 2048 --param-r 8"; Algorithm = "yespower"} #TDC tidecoin
    [PSCustomObject]@{MainAlgorithm = "yespowerURX"; Params = ""} #Yespower Uranium-X (URX)
    [PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #zr5

    #GPU or ASIC - never profitable
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""; NeverProfitable = $true} #Bitcore
    [PSCustomObject]@{MainAlgorithm = "blake"; Params = ""; NeverProfitable = $true} #blake
    [PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""; NeverProfitable = $true} #Blakecoin
    [PSCustomObject]@{MainAlgorithm = "blake2b"; Params = ""; NeverProfitable = $true} #Blake2b, new with v3.9.6.2
    [PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""; ExcludePoolName = "Nicehash"; NeverProfitable = $true} #blake2s
    [PSCustomObject]@{MainAlgorithm = "bmw512"; Params = ""; NeverProfitable = $true} #bmw512
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = ""; NeverProfitable = $true} #C11
    [PSCustomObject]@{MainAlgorithm = "deep"; Params = ""; NeverProfitable = $true} #deep
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = ""; NeverProfitable = $true} #HEX
    [PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""; NeverProfitable = $true} #dmd-gr
    [PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""; NeverProfitable = $true} #Groestl
    [PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""; NeverProfitable = $true} #Keccak
    [PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""; NeverProfitable = $true} #keccakc
    [PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""; NeverProfitable = $true} #Lbry
    [PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""; NeverProfitable = $true} #Lyra2RE2
    [PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; NeverProfitable = $true} #lyra2h
    [PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""; NeverProfitable = $true} #lyra2re
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""; NeverProfitable = $true} #Lyra2z, ZCoin
    [PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""; NeverProfitable = $true} #MyriadGroestl
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""; NeverProfitable = $true} #NeoScrypt
    [PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""; NeverProfitable = $true} #Nist5
    [PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""; NeverProfitable = $true} #pentablake
    [PSCustomObject]@{MainAlgorithm = "phi1612"; Params = ""; NeverProfitable = $true} #phi1612
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""; NeverProfitable = $true} #PHI2
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = ""; NeverProfitable = $true} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "quark"; Params = ""; NeverProfitable = $true} #Quark
    [PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""; NeverProfitable = $true} #Qubit
    [PSCustomObject]@{MainAlgorithm = "scrypt"; Params = ""; NeverProfitable = $true} #Scrypt
    [PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""; NeverProfitable = $true} #sha256d
    [PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""; NeverProfitable = $true} #sha256t
    [PSCustomObject]@{MainAlgorithm = "sha3d"; Params = ""; NeverProfitable = $true} #sha3d, BSHA3
    [PSCustomObject]@{MainAlgorithm = "sib"; Params = ""; NeverProfitable = $true} #Sib
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = ""; NeverProfitable = $true} #Skein
    [PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""; NeverProfitable = $true} #skein2
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""; NeverProfitable = $true} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""; NeverProfitable = $true} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""; NeverProfitable = $true} #Tribus
    [PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""; NeverProfitable = $true} #BlakeVanilla
    [PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""; NeverProfitable = $true} #Veltor
    [PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""; NeverProfitable = $true} #whirlpoolx
    [PSCustomObject]@{MainAlgorithm = "x11"; Params = ""; NeverProfitable = $true} #X11
    [PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""; NeverProfitable = $true} #X11evo
    [PSCustomObject]@{MainAlgorithm = "x13"; Params = ""; NeverProfitable = $true} #x13
    [PSCustomObject]@{MainAlgorithm = "x13sm3"; Params = ""; NeverProfitable = $true} #x13sm3
    [PSCustomObject]@{MainAlgorithm = "x14"; Params = ""; NeverProfitable = $true} #x14
    [PSCustomObject]@{MainAlgorithm = "x15"; Params = ""; NeverProfitable = $true} #x15
    [PSCustomObject]@{MainAlgorithm = "x13bcd"; Params = ""; NeverProfitable = $true} #bcd
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; NeverProfitable = $true} #x16r
    [PSCustomObject]@{MainAlgorithm = "x16rt"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; NeverProfitable = $true} #x16rt
    [PSCustomObject]@{MainAlgorithm = "x16rt-veil"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; NeverProfitable = $true} #x16rt-veil
    [PSCustomObject]@{MainAlgorithm = "x16rv2"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; NeverProfitable = $true} #x16rv2
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""; NeverProfitable = $true} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = ""; NeverProfitable = $true} #X17
    [PSCustomObject]@{MainAlgorithm = "x20r"; Params = ""; NeverProfitable = $true} #x20r
    [PSCustomObject]@{MainAlgorithm = "x21s"; Params = ""; NeverProfitable = $true} #x21s
    [PSCustomObject]@{MainAlgorithm = "x22i"; Params = ""; NeverProfitable = $true} #x22i
    [PSCustomObject]@{MainAlgorithm = "x25x"; Params = ""; NeverProfitable = $true} #x25x
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = ""; NeverProfitable = $true} #Xevan
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

    $Commands | Where-Object {(-not $_.LinuxOnly -or $IsLinux) -and (-not $_.NeverProfitable -or $Session.Config.EnableNeverprofitableAlgos)} | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm "$(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm})"

        $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
        $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity "})"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
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
					Arguments      = "-b `$mport -a $(if ($Miner_Coin -and $_.$Miner_Coin) {$_.$Miner_Coin} else {$_.MainAlgorithm}) -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
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
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ExcludePoolName = $_.ExcludePoolName
				}
			}
		}
    }
}
