using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$ManualUri = "https://github.com/rplant8/cpuminer-opt-rplant/releases"
$Port = "232{0:d2}"
$DevFee = 0.0
$Version = "5.0.41"

if ($IsLinux) {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx512 -and $f.sha -and $f.vaes){'avx512-sha-vaes'}elseif($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'sse42-aes'}elseif($f.sse42){'sse42'}elseif($Global:GlobalCPUInfo.Vendor -eq "AMD"){'sse2amd'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.41-rplant/cpuminer-opt-linux-5.0.41a.tar.gz"
} else {
    $Path = ".\Bin\CPU-Rplant\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'ryzen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'sse42-aes'}elseif($f.sse42){'sse42'}elseif($Global:GlobalCPUInfo.Vendor -eq "AMD"){'sse2amd'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.41-rplant/cpuminer-opt-win-5.0.41.zip"
    #$Version = "5.0.29"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #Allium (GRLC)
    [PSCustomObject]@{MainAlgorithm = "anime"; Params = ""} #Anime (ANI)
    [PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""} #Argon2d-crds (CRDS)
    [PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""} #Argon2d500 (DYN)
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""} #Argon2d4096 (UIS)
    [PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""} #Shabal-256
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #BMW-256
    [PSCustomObject]@{MainAlgorithm = "circcash"; Params = ""} #CircCash
    [PSCustomObject]@{MainAlgorithm = "dpowhash"; Params = ""} #DpowHash (DPC)
    [PSCustomObject]@{MainAlgorithm = "gr"; Params = ""; FaultTolerance = 8; ExtendInterval = 3; ExcludePoolName = "C3pool|MoneroOcean"} #Ghostrider/Take5
    [PSCustomObject]@{MainAlgorithm = "heavyhash"; Params = ""} #HeavyHash
    [PSCustomObject]@{MainAlgorithm = "hodl"; Params = ""} #Hodl
    [PSCustomObject]@{MainAlgorithm = "lyra2a40"; Params = ""; LinuxOnly = $true} #Lyra2AA40/APPLE
    [PSCustomObject]@{MainAlgorithm = "lyra2h"; Params = ""; LinuxOnly = $true} #Lyra2h
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""} #LYRA2z
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = ""; ExcludePoolName = "Zpool"} #Lyra2z330
    [PSCustomObject]@{MainAlgorithm = "memehashv2"; Params = ""; LinuxOnly = $true} #MemeHashV2/PEPE2
    [PSCustomObject]@{MainAlgorithm = "mike"; FaultTolerance = 8; ExtendInterval = 3; Params = ""} #Mike/VKAX
    [PSCustomObject]@{MainAlgorithm = "minotaur"; Params = ""} #Minotaur/RING
    [PSCustomObject]@{MainAlgorithm = "minotaurx"; Params = ""} #Minotaurx
    [PSCustomObject]@{MainAlgorithm = "rwahash"; Params = ""; LinuxOnly = $true} #RwaHash
    #[PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""} #ScryptN2, CpuminerVerium and CpuminerJayddee faster
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""; LinuxOnly = $true} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""} #Shavite3
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""} #Timetravel7 (MAC)
    [PSCustomObject]@{MainAlgorithm = "x22"; Params = ""} #X22 from v4.5.20 on
    ####[PSCustomObject]@{MainAlgorithm = "x33"; Params = ""} #X33 (QRN) from v4.5.16 on
    [PSCustomObject]@{MainAlgorithm = "hashx7"; Params = ""} #HashX7/6ZIP
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16
    #[PSCustomObject]@{MainAlgorithm = "yescryptr16v2"; GLT="yescryptr16v2glt"; Params = ""} #YescryptR16v2
    #[PSCustomObject]@{MainAlgorithm = "yescryptr24"; GLT="yescryptr24glt"; Params = ""} #YescryptR24
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr32glt"; Params = ""} #YescryptR32GLT
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8
    [PSCustomObject]@{MainAlgorithm = "yescryptr8g"; Params = ""} #YescryptR8g (KOTO)
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16
    [PSCustomObject]@{MainAlgorithm = "yespowerARWN"; Params = ""} #Yespower Arowanacoin (ARWN)
    [PSCustomObject]@{MainAlgorithm = "yespowerIC"; Params = ""} #Yespower IsotopeC (IC)
    [PSCustomObject]@{MainAlgorithm = "yespowerITC"; Params = ""} #Yespower Intercoin (ITC)
    [PSCustomObject]@{MainAlgorithm = "yespowerIOTS"; Params = ""} #Yespower .. (IOTS)
    [PSCustomObject]@{MainAlgorithm = "yespowerLITB"; Params = ""} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerLTNCG"; Params = ""} #Yespower LighningCash-Gold v3 (LTNCG)
    [PSCustomObject]@{MainAlgorithm = "yespowerMGPC"; Params = ""} #Yespower Magpiecoin (MGPC)
    [PSCustomObject]@{MainAlgorithm = "yespowerRES"; Params = ""} #Yespower Resistance (RES)
    [PSCustomObject]@{MainAlgorithm = "yespowerSUGAR"; Params = ""} #Yespower SugarChain (SUGAR)
    [PSCustomObject]@{MainAlgorithm = "yespowerTIDE"; Params = ""} #Yespower Tidecoin (TDC)
    [PSCustomObject]@{MainAlgorithm = "yespowerURX"; Params = ""} #Yespower Uranium-X (URX)
    [PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #Ziftr

    #GPU or ASIC - never profitable
    [PSCustomObject]@{MainAlgorithm = "blake"; Params = ""; NeverProfitable = $true} #Blake256r14
    [PSCustomObject]@{MainAlgorithm = "blake2b"; Params = ""; NeverProfitable = $true} #Blake2b 256
    [PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""; NeverProfitable = $true} #Blake-2 s
    [PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""; NeverProfitable = $true} #Blake256r8
    [PSCustomObject]@{MainAlgorithm = "bmw512"; Params = ""; NeverProfitable = $true} #BMW-512
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = ""; NeverProfitable = $true} #C11 (CHC)
    [PSCustomObject]@{MainAlgorithm = "decred"; Params = ""; NeverProfitable = $true} #Deepcoin (DCN)
    [PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""; NeverProfitable = $true} #Diamond
    [PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""; NeverProfitable = $true} #Groestl
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = ""; NeverProfitable = $true} #h16r-hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""; NeverProfitable = $true} #Espers
    [PSCustomObject]@{MainAlgorithm = "jha"; Params = ""; NeverProfitable = $true} #Jackpot
    [PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""; NeverProfitable = $true} #Maxcoin
    [PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""; NeverProfitable = $true} #Creative
    [PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""; NeverProfitable = $true} #LBRY
    [PSCustomObject]@{MainAlgorithm = "lyra2re"; Params = ""; NeverProfitable = $true} #LYRA2
    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Params = ""; NeverProfitable = $true} #LYRAv2
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; Params = ""; NeverProfitable = $true} #Lyrav2v3
    [PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""; NeverProfitable = $true} #Myriad-groestl
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""; NeverProfitable = $true} #NeoScrypt(128,2,1)
    [PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""; NeverProfitable = $true} #NIST5
    [PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""; NeverProfitable = $true} #5xBlake512
    [PSCustomObject]@{MainAlgorithm = "phi1612"; Params = ""; NeverProfitable = $true} #Phi
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""; NeverProfitable = $true} #Phi2
    [PSCustomObject]@{MainAlgorithm = "phi5"; Params = ""; NeverProfitable = $true} #Combode Coin
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = ""; NeverProfitable = $true} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = ""; MaxRejectedShareRatio = 0.7} #Yespower2b, Jayddee faster
    [PSCustomObject]@{MainAlgorithm = "phichox"; Params = ""; NeverProfitable = $true} #phiCHOX/CHOX algo has changed 03/01/2022
    [PSCustomObject]@{MainAlgorithm = "quark"; Params = ""; NeverProfitable = $true} #Quark
    [PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""; NeverProfitable = $true} #Qubit
    ###[PSCustomObject]@{MainAlgorithm = "qureno"; Params = ""; NeverProfitable = $true} #X33 (new QRN) from v4.5.17 on
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = ""; NeverProfitable = $true} #Skein
    [PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""; NeverProfitable = $true} #Skein 2 - Wood coin
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""; NeverProfitable = $true} #SIGT
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""; NeverProfitable = $true} #Sono    
    [PSCustomObject]@{MainAlgorithm = "timetravel10"; Params = ""; NeverProfitable = $true} #Bitcore (BTX)
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""; NeverProfitable = $true} #Denarius (DNR)
    [PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""; NeverProfitable = $true} #Veltor
    [PSCustomObject]@{MainAlgorithm = "whirlpool"; Params = ""; NeverProfitable = $true} #Whirlpool
    [PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""; NeverProfitable = $true} #WhirlpoolX
    [PSCustomObject]@{MainAlgorithm = "x11"; Params = ""; NeverProfitable = $true} #Dash
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

        $DeviceParams = "$(if ($CPUThreads){" -t $CPUThreads"})$(if ($CPUAffinity){" --cpu-affinity $CPUAffinity --no-smart"})"

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
					Arguments      = "-b `$mport -a $(if ($Miner_Coin -and $_.$Miner_Coin) {$_.$Miner_Coin} else {$_.MainAlgorithm}) -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) --no-doh $($_.Params)"
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
