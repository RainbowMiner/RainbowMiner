﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\NVIDIA-TPruvot\ccminer-x64.exe"
$ManualUri = "https://github.com/tpruvot/ccminer/releases"
$Port = "114{0:d2}"
$DevFee = 0.0
$Version = "2.3.1"

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3.1-tpruvot/ccminer-2.3.1-cuda10.1.7z"
        Cuda = "10.1"
    }
)

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #GPU - profitable 20/04/2018
    #[PSCustomObject]@{MainAlgorithm = "allium"; Params = "-N 1"} #Allium
    #[PSCustomObject]@{MainAlgorithm = "bastion"; Params = ""} #bastion
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    [PSCustomObject]@{MainAlgorithm = "blake2b"; Params = ""; ExtendInterval = 2; CoinSymbols = @("TNET")} #Blake2b
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #bmw
    #[PSCustomObject]@{MainAlgorithm = "c11/flax"; Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""} # CryptoNight-Lite
    #[PSCustomObject]@{MainAlgorithm = "deep"; Params = ""} #deep
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""} #dmd-gr
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
    [PSCustomObject]@{MainAlgorithm = "exosis"; Params = "-N 1"} #Exosis
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""} #fresh
    #[PSCustomObject]@{MainAlgorithm = "fugue256"; Params = ""} #Fugue256
    #[PSCustomObject]@{MainAlgorithm = "graft"; Params = ""; ExcludePoolName = "^Nicehash"} #CryptoNightV7
    [PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""; FaultTolerance = 0.5} #Groestl
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = "-N 1"; FaultTolerance = 0.5} #HMQ1725
    #[PSCustomObject]@{MainAlgorithm = "jackpot"; Params = ""} #JHA
    [PSCustomObject]@{MainAlgorithm = "jha"; Params = "-N 1"} #JHA
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = "-N 1"} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "keccakc"; Params = "-N 1"} #keccakc
    #[PSCustomObject]@{MainAlgorithm = "luffa"; Params = ""} #Luffa
    #[PSCustomObject]@{MainAlgorithm = "lyra2"; Params = ""} #lyra2re
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2RE2
    #[PSCustomObject]@{MainAlgorithm = "lyra2v3"; Params = "-N 1"} #Lyra2RE3
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = "-N 1 --submit-stale"} #Lyra2z, ZCoin        
    #[PSCustomObject]@{MainAlgorithm = "monero"; Params = "-N 1"; ExcludePoolName = "^Nicehash"} #CryptoNightV8
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #NeoScrypt
    #[PSCustomObject]@{MainAlgorithm = "penta"; Params = ""} #Pentablake
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = " -N 1"} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = " -N 3"}
    #[PSCustomObject]@{MainAlgorithm = "polytimos"; Params = ""} #Polytimos
    #[PSCustomObject]@{MainAlgorithm = "scrypt-jane"; Params = ""} #scryptjane:nf
    [PSCustomObject]@{MainAlgorithm = "sha256q"; Params = "-N 1"} #sha256q
    [PSCustomObject]@{MainAlgorithm = "sha256t"; Params = "-N 1"} #sha256t
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""} #skein2
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = "-N 1"} #SonoA
    [PSCustomObject]@{MainAlgorithm = "stellite"; Params = ""} # CryptoNightV3
    #[PSCustomObject]@{MainAlgorithm = "s3"; Params = ""} #S3
    #[PSCustomObject]@{MainAlgorithm = "scrypt:10"; Params = "-N 1 --cpu-priority 1 --lookup-gap=2"; ExtendInterval = 3; NoCPUMining = $true} #ScryptN11
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "-N 1"} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    #[PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""} #Veltor
    #[PSCustomObject]@{MainAlgorithm = "whirlpool"; Params = ""} #Whirlpool
    #[PSCustomObject]@{MainAlgorithm = "whirlpoolx"; Params = ""} #whirlpoolx
    #[PSCustomObject]@{MainAlgorithm = "wildkeccak"; Params = ""} #wildkeccak
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""} #X11evo
    [PSCustomObject]@{MainAlgorithm = "x12"; Params = ""} #X12
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""} #X16r
    #[PSCustomObject]@{MainAlgorithm = "X16s"; Params = ""} #X16s
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #x17
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #zr5

    # ASIC - never profitable 20/04/2018
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #blake
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "quark"; Params = ""} #Quark
    #[PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""} #Qubit
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "scrypt"; Params = ""} #Scrypt
    #[PSCustomObject]@{MainAlgorithm = "scrypt:N"; Params = ""} #scrypt:N
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""} #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sia"; Params = ""} #SiaCoin
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""} #Sib
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "x11"; Params = ""} #X11
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""} #x13
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #x14
    #[PSCustomObject]@{MainAlgorithm = "x15"; Params = ""} #x15
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
    }
}

if (-not $Cuda) {return}

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbols -or $Pools.$Algorithm_Norm.CoinSymbol -in $_.CoinSymbols)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-T 50000 -R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    NoCPUMining    = $_.NoCPUMining
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    })
}