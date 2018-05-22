using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-TPruvot\ccminer.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.5-tpruvot/ccminer-x86-2.2.5-cuda9.7z"

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    #"bastion" = "" #bastion
    #"bitcore" = " -i 21" #Bitcore
    #"bmw" = "" #bmw
    #"c11" = "" #C11
    #"deep" = "" #deep
    #"dmd-gr" = "" #dmd-gr
    #"equihash" = "" #Equihash
    #"fresh" = "" #fresh
    #"fugue256" = "" #Fugue256
    #"groestl" = "" #Groestl
    "hmq1725" = "" #HMQ1725
    #"jackpot" = "" #JackPot
    "jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"keccakc" = "" #keccakc
    #"luffa" = "" #Luffa
    #"lyra2" = "" #lyra2re
    #"lyra2v2" = "" #Lyra2RE2
    "lyra2z" = " -N 1 -i 21" #Lyra2z, ZCoin
    #"neoscrypt" = "" #NeoScrypt
    #"penta" = "" #Pentablake
    ###"phi" = " -N 1" #PHI spmod is faster
    #"polytimos" = "" #Polytimos
    #"scryptjane:nf" = "" #scryptjane:nf
    "sha256t" = "" #sha256t
    #"skein" = "" #Skein
    #"skein2" = "" #skein2
    #"skunk" = "" #Skunk
    #"s3" = "" #S3
    "timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus (enemyz 1.10 is faster)
    #"veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    #"wildkeccak" = "" #wildkeccak
    #"x11evo" = "" #X11evo
    #"x12" = "" #X12
    #"x16r" = "" #X16r
    #"X16s" = "" #X16s
    #"x17" = "" #x17
    #"zr5" = "" #zr5

    # ASIC - never profitable 20/04/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"lbry" = "" #Lbry
    #"decred" = "" #Decred
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"scrypt" = "" #Scrypt
    #"scrypt:N" = "" #scrypt:N
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"sib" = "" #Sib
    #"vanilla" = "" #BlakeVanilla
    #"x11" = "" #X11
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "lyra2z" = 4
}

$DeviceIDsAll = Get-GPUlist "NVIDIA"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll -join ',') -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_) --submit-stale"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
    }
}
