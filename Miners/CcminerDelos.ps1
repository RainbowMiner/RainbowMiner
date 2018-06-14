using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Delos\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3a-ccminerdelos/DelosMiner1.3.0a-x86-cu91.zip"
$UriManual = "https://bitcointalk.org/index.php?topic=4344544"
$Port = "113{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #GPU - profitable 29/05/2018
    "bastion"     = "" # Hefty bastion, untested
    "bitcore"     = "" # Timetravel-10
    "bmw"         = "" # BMW 256, untested
    "cryptolight" = "" # AEON cryptonight (MEM/2)
    "c11/flax"    = "" # X11 variant, untested
    "deep"        = "" # Deepcoin, untested
    "equihash"    = "" # Zcash Equihash
    "dmd-gr"      = "" # Diamond-Groestl, untested
    "fresh"       = "" # Freshcoin (shavite 80), untested
    "fugue256"    = "" # Fuguecoin, untested
    "groestl"     = "" # Groestlcoin
    "hmq1725"     = "" # Doubloons / Espers
    "hsr"         = "" # HSR
    "jackpot"     = "" # JHA v8, untested
    "keccak"      = "" # Deprecated Keccak-256
    "keccakc"     = "" # Keccak-256 (CreativeCoin)
    "lbry"        = "" # LBRY Credits (Sha/Ripemd)
    "luffa"       = "" # Joincoin, untested
    "lyra2"       = "" # CryptoCoin
    "lyra2v2"     = "" # VertCoin
    "lyra2z"      = "" # ZeroCoin (3rd impl)
    "neoscrypt"   = "" # FeatherCoin, Phoenix, UFO...
    "penta"       = "" # Pentablake hash (5x Blake 512), untested
    "phi"         = "" # BHCoin
    "polytimos"   = "" # Politimos, untested
    "sha256t"     = "" # SHA256 x3
    "sib"         = "" # Sibcoin (X11+Streebog)
    "scrypt-jane" = "" # Scrypt-jane Chacha, untested
    "skein"       = "" # Skein SHA2 (Skeincoin)
    "skein2"      = "" # Double Skein (Woodcoin), untested
    "skunk"       = "" # Skein Cube Fugue Streebog
    "s3"          = "" # S3 (1Coin), untested
    "timetravel"  = "" # Machinecoin permuted x8
    "tribus"      = "" # Denarius, untested
    "vanilla"     = "" # Blake256-8 (VNL), untested
    "veltor"      = "" # Thorsriddle streebog, untested
    "whirlcoin"   = "" # Old Whirlcoin (Whirlpool algo), untested
    "whirlpool"   = "" # Whirlpool algo, untested
    "x11evo"      = "" # Permuted x11 (Revolver)
    #"x16r"        = "" # X16R (Raven)
    "x16s"        = "" # X16S
    "x17"         = "" # X17
    "wildkeccak"  = "" # Boolberry, untested
    "zr5"         = "" # ZR5 (ZiftrCoin), untested
            
    # ASIC - never profitable 20/04/2018
    #"blake"      = "" #blake
    #"blakecoin"  = "" #Blakecoin
    #"blake2s"    = "" #Blake2s
    #"myr-gr"     = "" #MyriadGroestl
    #"nist5"      = "" #Nist5
    #"quark"      = "" #Quark
    #"qubit"      = "" #Qubit
    #"vanilla"    = "" #BlakeVanilla
    #scrypt"      = "" #Scrypt
    #"sha256d"    = "" #sha256d
    #"sia"        = "" #SiaCoin
    #"x11"        = "" #X11
    #"x13"        = "" #x13
    #"x14"        = "" #x14
    #"x15"        = "" #x15
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @(Get-DeviceModel $_)) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-r 0 -b $($Miner_Port) -d $($DeviceIDsAll) -a $_ -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --submit-stale$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Ccminer"
            Port = $Miner_Port
            Wrap = $false
            URI = $Uri
            DevFee = 1.0
        }
    }
}