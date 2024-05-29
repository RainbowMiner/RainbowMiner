using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$ManualUri = "https://github.com/JayDDee/cpuminer-opt/releases"
$Port = "200{0:d2}"
$DevFee = 0.0
$Version = "24.3"

$Path = $null

if ($IsLinux) {
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        if ($Global:GlobalCPUInfo.Architecture -eq 8) {
            $Path = ".\Bin\CPU-JayDDee\cpuminer-armv8$($f=$Global:GlobalCPUInfo.Features;$(if($f.sve2 -and $f.sha2 -and $f.aes){'-aes-sha2-sve2'}elseif($f.sha2 -and $f.aes){'-aes-sha2'}elseif($f.aes){'-aes'}elseif($f.sha2){'-sha2'}))"
            $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v24.3-jayddee/cpuminer-opt-24.3-arm.7z"
        }
    } else {    
        $Path = ".\Bin\CPU-JayDDee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx512) {'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'}))"
        $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v24.3-jayddee/cpuminer-opt-24.3-linux.7z"
    }
} else {
    $Path = ".\Bin\CPU-JayDDee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx512 -and $f.sha -and $f.vaes){'avx512-sha-vaes'}elseif($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.vaes){'avx2-sha-vaes'}elseif($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v24.3-jayddee/cpuminer-opt-24.3-windows.zip"
}

if ($Path -eq $null) {return}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #Garlicoin
    [PSCustomObject]@{MainAlgorithm = "anime";  Params = ""} #Anime
    #[PSCustomObject]@{MainAlgorithm = "argon2"; Params = ""} #Argon2
    [PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""} #Argon2Credits (argon2d-crds)
    [PSCustomObject]@{MainAlgorithm = "argon2d500";  Params = ""} #Argon2Dynamic (argon2d-dyn)
    [PSCustomObject]@{MainAlgorithm = "argon2d5096";  Params = ""} #Argon2Unitus (argon2d-uis)
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""} #axiom
    [PSCustomObject]@{MainAlgorithm = "bastion"; Params = ""} #bastion
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #bmw
    [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = "--param-key `"CPUpower: The number of CPU working or available for proof-of-work mining`""; Algorithm = "yespower"} #CpuPower
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""} #HMQ1725
    #[PSCustomObject]@{MainAlgorithm = "hodl"; Params = ""} #HODL
    [PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #JHA
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; Params = ""} #Lyra2v3
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""} #lyra2z330, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""} #m7m, (CpuminerRKZ faster)
    [PSCustomObject]@{MainAlgorithm = "minotaur"; Params = ""} #Minotaur/RNG
    [PSCustomObject]@{MainAlgorithm = "minotaurx"; Params = ""} #MinotaurX/AVN
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = "--param-n 2048 --param-r 32 --param-key `"Now I am become Death, the destroyer of worlds`""; Algorithm = "yespower-b2b"} #power2b
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
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #yescryptr16, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #yescryptr32, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #yescryptr8, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""} #yescryptr8g, KOTO
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #YesPower
    [PSCustomObject]@{MainAlgorithm = "yespowerARWN"; Params = "--param-n 2048 --param-r 32 --param-key `"ARWN`""; Algorithm = "yespower"} #Arrowana
    [PSCustomObject]@{MainAlgorithm = "yespowerIC"; Params = "--param-n 2048 --param-r 32 --param-key `"IsotopeC`""; Algorithm = "yespower"} #Yespower IsotopeC (IC)
    [PSCustomObject]@{MainAlgorithm = "yespowerIOTS"; Params = "--param-n 2048 --param-key `"Iots is committed to the development of IOT`""; Algorithm = "yespower"} #Yespower .. (IOTS)
    [PSCustomObject]@{MainAlgorithm = "yespowerLITB"; Params = "--param-n 2048 --param-r 32 --param-key `"LITBpower: The number of LITB working or available for proof-of-work mini`""; Algorithm = "yespower"} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerLTNCG"; Params = "--param-n 2048 --param-r 32 --param-key `"LTNCGYES`""; Algorithm = "yespower"} #Yespower LighningCash-Gold v3 (LTNCG)
    [PSCustomObject]@{MainAlgorithm = "yespowerMGPC"; Params = "--param-n 2048 --param-r 32 --param-key `"Magpies are birds of the Corvidae family.`""; Algorithm = "yespower"} #Magpiecoin
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YesPowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "yespowerSUGAR"; Params = "--param-n 2048 --param-r 32 --param-key `"Satoshi Nakamoto 31/Oct/2008 Proof-of-work is essentially one-CPU-one-vote`""; Algorithm = "yespower"} #Yespower SugarChain (SUGAR)
    [PSCustomObject]@{MainAlgorithm = "yespowerTIDE"; Params = "--param-n 2048 --param-r 8"; Algorithm = "yespower"} #TDC tidecoin
    [PSCustomObject]@{MainAlgorithm = "yespowerURX"; Params = "--param-n 2048 --param-r 32 --param-key `"UraniumX`""; Algorithm = "yespower"} #Yespower Uranium-X (URX)
    [PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #zr5

    #GPU or ASIC - never profitable
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #blake
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "blake2b"; Params = ""} #Blake2b, new with v3.9.6.2
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""; ExcludePoolName = "Nicehash"} #blake2s
    #[PSCustomObject]@{MainAlgorithm = "bmw512"; Params = ""} #bmw512
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""} #cryptolight
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""} #CryptoNight
    #[PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = ""} #CryptoNightV7
    #[PSCustomObject]@{MainAlgorithm = "deep"; Params = ""} #deep
    #[PSCustomObject]@{MainAlgorithm = "drop"; Params = ""} #drop
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""} #fresh
    #[PSCustomObject]@{MainAlgorithm = "heavy"; Params = ""} #heavy
    #[PSCustomObject]@{MainAlgorithm = "hex"; Params = ""} #HEX
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""} #dmd-gr
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""} #Groestl
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
    #[PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""} #pentablake
    #[PSCustomObject]@{MainAlgorithm = "phi1612"; Params = ""} #phi1612
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    #[PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""} #pluck
    #[PSCustomObject]@{MainAlgorithm = "scrypt:N"; Params = ""} #scrypt:N
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""} #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""} #sha256t
    #[PSCustomObject]@{MainAlgorithm = "sha3d"; Params = ""} #sha3d, BSHA3
    #[PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""} #shavite3
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""} #skein2
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""} #Sonoa
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""} #Veltor
    #[PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""} #whirlpoolx
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""} #x13
    #[PSCustomObject]@{MainAlgorithm = "x13sm3"; Params = ""} #x13sm3
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #x14
    #[PSCustomObject]@{MainAlgorithm = "x15"; Params = ""} #x15
    #[PSCustomObject]@{MainAlgorithm = "x13bcd"; Params = ""} #bcd
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16r
    #[PSCustomObject]@{MainAlgorithm = "x16rt"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rt
    #[PSCustomObject]@{MainAlgorithm = "x16rt-veil"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rt-veil
    #[PSCustomObject]@{MainAlgorithm = "x16rv2"; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #x16rv2
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""} #X16s
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #X17
    #[PSCustomObject]@{MainAlgorithm = "x20r"; Params = ""} #x20r
    #[PSCustomObject]@{MainAlgorithm = "x21s"; Params = ""} #x21s
    #[PSCustomObject]@{MainAlgorithm = "x22i"; Params = ""} #x22i
    #[PSCustomObject]@{MainAlgorithm = "x25x"; Params = ""} #x25x
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

$VerthashDatFile = Join-Path $Session.MainPath "Bin\CPU-JayDDee\verthash.dat"    
if (-not (Test-Path $VerthashDatFile)) {
    $VerthashDatFile = if ($IsLinux) {"$env:HOME/.vertcoin/verthash.dat"} else {"$env:APPDATA\Vertcoin\verthash.dat"}
    if (-not (Test-Path $VerthashDatFile) -or (Get-Item $VerthashDatFile).length -lt 1.19GB) {
        $VerthashDatFile = Join-Path $Session.MainPath "Bin\Common\verthash.dat"
    }
}

$Global:DeviceCache.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes.CPU.Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
        $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}

        $IsVerthash = $Algorithm_Norm_0 -eq "Verthash"
        $VerthashDatFile_Quoted = "`"$VerthashDatFile`""

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity"})$(if ($IsVerthash) {" --data-file $VerthashDatFile_Quoted"})"

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = if ($_.Path) {$_.Path} else {$Path}
					Arguments      = "-b 127.0.0.1:`$mport -a $(if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) -q $($_.Params)"
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
                    PrerequisitePath = if ($IsVerthash) {$VerthashDatFile} else {$null}
                    PrerequisiteURI  = "$(if ($IsVerthash) {"https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-verthash/verthash.dat"})"
                    PrerequisiteMsg  = "$(if ($IsVerthash) {"Downloading verthash.dat (1.2GB) in the background, please wait!"})"
                    ExcludePoolName = $_.ExcludePoolName
				}
			}
		}
    })
}
