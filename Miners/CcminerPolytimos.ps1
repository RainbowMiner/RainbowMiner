using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Polytimos\ccminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2-ccminerpolytimos/ccminerpolytimos_1.2.zip"
$Port = "100{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    #"blake2s" = "" #Blake2s XVG
    #"c11" = "" #c11
    "hsr" = " -N 1" #HSR, HShare (fastest)
    "keccak" = " -N 1" #Keccak (Excavator is faster)
    #"lyra2" = "" #Lyra2RE
    "lyra2v2" = " -N 1" #lyra2v2 (fastest)
    "polytimos" = " -N 1" #Polytimos
    "skein" = " -N 1" #Skein
    "skein2" = " -N 1" #skein2
    "veltor" = " -N 1" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"x11evo" = "" #X11evo
    "x17" = " -N 1" #x17 (fastest)

    # ASIC - never profitable 20/04/2018
    #"blake2s" = "" #Blake2s
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"cryptolight" = "" #cryptolight
    #"cryptonight" = "" #CryptoNight
    #"decred" = "" #Decred
    #"lbry" = " -N 1" #Lbry (fastest)
    #"myr-gr" = " -N 1" #MyriadGroestl (fastest)
    #"nist5" = " -N 1" #Nist5 (fastest)
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"sib" = "" #Sib
    #"x11" = "" #X11
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
    #"bitcore" = "" #Bitcore
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @(Get-DeviceModel $_)) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
        }
    }
}