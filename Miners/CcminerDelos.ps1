using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Delos\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3a-ccminerdelos/DelosMiner1.3.0a-x86-cu91.zip"
$UriManual = "https://bitcointalk.org/index.php?topic=4344544"
$Port = "113{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #GPU - profitable 29/05/2018
    #[PSCustomObject]@{MainAlgorithm = "bastion"; Params = ""}, # Hefty bastion, untested
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""}, # Timetravel-10
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""}, # BMW 256, untested
    #[PSCustomObject]@{MainAlgorithm = "cryptolight"; Params = ""}, # AEON cryptonight (MEM/2)
    #[PSCustomObject]@{MainAlgorithm = "c11/flax"; Params = ""}, # X11 variant, untested
    #[PSCustomObject]@{MainAlgorithm = "deep"; Params = ""}, # Deepcoin, untested
    #[PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""}, # Zcash Equihash
    #[PSCustomObject]@{MainAlgorithm = "dmd-gr"; Params = ""}, # Diamond-Groestl, untested
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""}, # Freshcoin (shavite 80), untested
    #[PSCustomObject]@{MainAlgorithm = "fugue256"; Params = ""}, # Fuguecoin, untested
    #[PSCustomObject]@{MainAlgorithm = "groestl"; Params = ""}, # Groestlcoin
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = ""}, # Doubloons / Espers
    #[PSCustomObject]@{MainAlgorithm = "hsr"; Params = ""}, # HSR
    #[PSCustomObject]@{MainAlgorithm = "jackpot"; Params = ""}, # JHA v8, untested
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""}, # Deprecated Keccak-256
    [PSCustomObject]@{MainAlgorithm = "keccakc"; Params = ""}, # Keccak-256 (CreativeCoin)
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""}, # LBRY Credits (Sha/Ripemd)
    #[PSCustomObject]@{MainAlgorithm = "luffa"; Params = ""}, # Joincoin, untested
    #[PSCustomObject]@{MainAlgorithm = "lyra2"; Params = ""}, # CryptoCoin
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""}, # VertCoin
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""}, # ZeroCoin (3rd impl)
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""}, # FeatherCoin, Phoenix, UFO...
    #[PSCustomObject]@{MainAlgorithm = "penta"; Params = ""}, # Pentablake hash (5x Blake 512), untested
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = ""}, # BHCoin
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = ""}, # Politimos, untested
    #[PSCustomObject]@{MainAlgorithm = "sha256t"; Params = ""}, # SHA256 x3
    #[PSCustomObject]@{MainAlgorithm = "sib"; Params = ""}, # Sibcoin (X11+Streebog)
    #[PSCustomObject]@{MainAlgorithm = "scrypt-jane"; Params = ""}, # Scrypt-jane Chacha, untested
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = ""}, # Skein SHA2 (Skeincoin)
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""}, # Double Skein (Woodcoin), untested
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""}, # Skein Cube Fugue Streebog
    #[PSCustomObject]@{MainAlgorithm = "s3"; Params = ""}, # S3 (1Coin), untested
    #[PSCustomObject]@{MainAlgorithm = "timetravel"; Params = ""}, # Machinecoin permuted x8
    #[PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""}, # Denarius, untested
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""}, # Blake256-8 (VNL), untested
    #[PSCustomObject]@{MainAlgorithm = "veltor"; Params = ""}, # Thorsriddle streebog, untested
    #[PSCustomObject]@{MainAlgorithm = "whirlcoin"; Params = ""}, # Old Whirlcoin (Whirlpool algo), untested
    #[PSCustomObject]@{MainAlgorithm = "whirlpool"; Params = ""}, # Whirlpool algo, untested
    #[PSCustomObject]@{MainAlgorithm = "x11evo"; Params = ""}, # Permuted x11 (Revolver)
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""}, # X16R (Raven)
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""}, # X16S
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} # X17
    #[PSCustomObject]@{MainAlgorithm = "wildkeccak"; Params = ""}, # Boolberry, untested
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""}, # ZR5 (ZiftrCoin), untested

    # ASIC - never profitable 20/04/2018
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""}, #blake
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""}, #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""}, #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""}, #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""}, #Nist5
    #[PSCustomObject]@{MainAlgorithm = "quark"; Params = ""}, #Quark
    #[PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""}, #Qubit
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = ""}, #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "sha256d"; Params = ""}, #sha256d
    #[PSCustomObject]@{MainAlgorithm = "sia"; Params = ""}, #SiaCoin
    #[PSCustomObject]@{MainAlgorithm = "x11"; Params = ""}, #X11
    #[PSCustomObject]@{MainAlgorithm = "x13"; Params = ""}, #x13
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""}, #x14
    #[PSCustomObject]@{MainAlgorithm = "x15"; Params = ""} #x15
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | ForEach {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --submit-stale $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = $_.FaultTolerance
            ExtendInterval = $_.ExtendInterval
            DevFee = 1.0
        }
    }
}