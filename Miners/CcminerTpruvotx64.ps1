using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-TPruvotx64\ccminer-x64.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/2.2.6-tpruvot/ccminer-x64-2.2.6-phi2-cuda9.7z"
$Port = "115{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    "allium" = " -N 1" #Allium
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
    "hmq1725" = " -N 1" #HMQ1725
    #"jackpot" = "" #JackPot
    "jha" = " -N 1" #JHA
    #"keccak" = "" #Keccak
    #"keccakc" = "" #keccakc
    #"luffa" = "" #Luffa
    #"lyra2" = "" #lyra2re
    #"lyra2v2" = "" #Lyra2RE2
    "lyra2z" = " -N 1 --submit-stale" #Lyra2z, ZCoin
    #"neoscrypt" = "" #NeoScrypt
    #"penta" = "" #Pentablake
    "phi" = " -N 1" #PHI spmod is faster
    #"polytimos" = "" #Polytimos
    #"scryptjane:nf" = "" #scryptjane:nf
    "sha256t" = " -N 1" #sha256t
    #"skein" = "" #Skein
    #"skein2" = "" #skein2
    #"skunk" = "" #Skunk
    #"s3" = "" #S3
    "timetravel" = " -N 1" #Timetravel
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