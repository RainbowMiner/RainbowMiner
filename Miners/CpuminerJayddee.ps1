using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\CPU-JayDDee\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha){'zen'}elseif($f.avx2){'avx2'}elseif($f.avx){'avx'}elseif($f.aes -and $f.sse42){'aes-sse42'}else{'sse2'})).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.9.6.1-jayddee/cpuminer-opt-3.9.6.1-windows.zip"
$ManualUri = "https://github.com/JayDDee/cpuminer-opt/releases"
$Port = "500{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""; ExtendInterval = 2} #Garlicoin
    [PSCustomObject]@{MainAlgorithm = "anime"; Params = ""; ExtendInterval = 2} #Anime
    [PSCustomObject]@{MainAlgorithm = "argon2"; Params = ""; ExtendInterval = 2} #Argon2
    [PSCustomObject]@{MainAlgorithm = "argon2d-crds"; Params = ""; ExtendInterval = 2} #Argon2Credits
    [PSCustomObject]@{MainAlgorithm = "argon2d-dyn"; Params = ""; ExtendInterval = 2} #Argon2Dynamic
    [PSCustomObject]@{MainAlgorithm = "argon2d-uis"; Params = ""; ExtendInterval = 2} #Argon2Unitus
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""; ExtendInterval = 2} #axiom
    [PSCustomObject]@{MainAlgorithm = "bastion"; Params = ""; ExtendInterval = 2} #bastion
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""; ExtendInterval = 2} #bmw
    #[PSCustomObject]@{MainAlgorithm = "bmw512"; Params = ""; ExtendInterval = 2} #bmw512
    #[PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = ""; ExtendInterval = 2} #CryptoNightV7
    [PSCustomObject]@{MainAlgorithm = "deep"; Params = ""; ExtendInterval = 2} #deep
    [PSCustomObject]@{MainAlgorithm = "drop"; Params = ""; ExtendInterval = 2} #drop
    [PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""; ExtendInterval = 2} #fresh
    [PSCustomObject]@{MainAlgorithm = "heavy"; Params = ""; ExtendInterval = 2} #heavy
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = ""; ExtendInterval = 2} #HEX
    [PSCustomObject]@{MainAlgorithm = "hodl"; Params = ""; ExtendInterval = 2} #HODL
    [PSCustomObject]@{MainAlgorithm = "jha"; Params = ""; ExtendInterval = 2} #JHA
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; Params = ""; ExtendInterval = 2} #Lyra2v3
    #[PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""; ExtendInterval = 2} #lyra2z330, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""; ExtendInterval = 2} #m7m
    [PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""; ExtendInterval = 2} #pentablake
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""; ExtendInterval = 2} #PHI2
    [PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""; ExtendInterval = 2} #pluck
    [PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""; ExtendInterval = 2} #Verium
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; Params = ""; ExtendInterval = 2} #ScryptN
    [PSCustomObject]@{MainAlgorithm = "scrypt:8192"; Params = ""; ExtendInterval = 2} #Scrypt8k
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; ExtendInterval = 2} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scryptjane:nf"; Params = ""; ExtendInterval = 2} #scryptjane:nf
    [PSCustomObject]@{MainAlgorithm = "sha256q"; Params = ""; ExtendInterval = 2} #sha256q
    [PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""; ExtendInterval = 2} #shavite3
    [PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""; ExtendInterval = 2} #skein2
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""; ExtendInterval = 2} #Sonoa
    #[PSCustomObject]@{MainAlgorithm = "x16rt-veil"; Params = ""; ExtendInterval = 2} #x16rt-veil
    [PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""; ExtendInterval = 2} #Veltor
    [PSCustomObject]@{MainAlgorithm = "x12"; Params = ""; ExtendInterval = 2} #x12
    #[PSCustomObject]@{MainAlgorithm = "x13bcd"; Params = ""; ExtendInterval = 2} #bcd
    #[PSCustomObject]@{MainAlgorithm = "x16rt"; Params = ""; ExtendInterval = 2} #x16rt
    #[PSCustomObject]@{MainAlgorithm = "x21s"; Params = ""; ExtendInterval = 2} #x21s
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""; ExtendInterval = 2} #Yescrypt
    #[PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""; ExtendInterval = 2} #yescryptr16, CpuminerOptBF faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""; ExtendInterval = 2} #yescryptr32, CpuminerOptBF faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""; ExtendInterval = 2} #yescryptr8, CpuminerOptBF faster
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""; ExtendInterval = 2} #YesPower
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""; ExtendInterval = 2} #YesPowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""; ExtendInterval = 2} #zr5

    #GPU or ASIC - never profitable
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""; ExtendInterval = 2} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""; ExtendInterval = 2} #blake
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""; ExtendInterval = 2} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""; ExtendInterval = 2} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""; ExtendInterval = 2} #cryptolight
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = ""; ExtendInterval = 2} #CryptoNight
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = ""; ExtendInterval = 2} #C11
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""; ExtendInterval = 2} #Decred
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""; ExtendInterval = 2} #dmd-gr
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""; ExtendInterval = 2} #Equihash
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""; ExtendInterval = 2} #Ethash
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""; ExtendInterval = 2} #Groestl
    #[PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""; ExtendInterval = 2} #HMQ1725
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""; ExtendInterval = 2} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""; ExtendInterval = 2} #keccakc
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""; ExtendInterval = 2} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""; ExtendInterval = 2} #Lyra2RE2
    #[PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; ExtendInterval = 2} #lyra2h
    #[PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""; ExtendInterval = 2} #lyra2re
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""; ExtendInterval = 2} #Lyra2z, ZCoin
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""; ExtendInterval = 2} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""; ExtendInterval = 2} #NeoScrypt
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""; ExtendInterval = 2} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""; ExtendInterval = 2} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "phi1612"; Params = ""; ExtendInterval = 2} #phi1612
    #[PSCustomObject]@{MainAlgorithm = "scrypt:N"; Params = ""; ExtendInterval = 2} #scrypt:N
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""; ExtendInterval = 2} #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""; ExtendInterval = 2} #sha256t
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""; ExtendInterval = 2} #Sib
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""; ExtendInterval = 2} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""; ExtendInterval = 2} #Skein
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""; ExtendInterval = 2} #Timetravel
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""; ExtendInterval = 2} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""; ExtendInterval = 2} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""; ExtendInterval = 2} #whirlpoolx
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""; ExtendInterval = 2} #X11evo
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""; ExtendInterval = 2} #x13
    #[PSCustomObject]@{MainAlgorithm = "x13sm3"; Params = ""; ExtendInterval = 2} #x13sm3
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""; ExtendInterval = 2} #x14
    #[PSCustomObject]@{MainAlgorithm = "x15"; Params = ""; ExtendInterval = 2} #x15
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 2} #x16r
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""; ExtendInterval = 2} #X16s
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""; ExtendInterval = 2} #X17
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

    $DeviceParams = "--hash-meter $(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Algorithm_Norm -ne "Lyra2z330" -or $Pools.$Algorithm_Norm.Name -ne "Zpool")) {
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