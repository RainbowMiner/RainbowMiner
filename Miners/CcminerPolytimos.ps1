using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Polytimos\ccminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2-ccminerpolytimos/ccminerpolytimos_1.2.zip"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    #"blake2s" = "" #Blake2s XVG
    #"c11" = "" #c11
    "hsr" = "" #HSR, HShare (fastest)
    "keccak" = "" #Keccak (Excavator is faster)
    #"lyra2" = "" #Lyra2RE
    "lyra2v2" = "" #lyra2v2 (fastest)
    "polytimos" = "" #Polytimos
    "skein" = "" #Skein
    "skein2" = "" #skein2
    "veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"x11evo" = "" #X11evo
    "x17" = " -i 20.5" #x17 (fastest)

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

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "lyra2v2" = 4
    "nist5"   = 4
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = (Get-GPUlist $Type) -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = $Type
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
    }
}