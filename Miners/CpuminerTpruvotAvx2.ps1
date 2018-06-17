using module ..\Include.psm1

$Path = ".\Bin\CPU-TPruvot\cpuminer-gw64-avx2.exe"
$Uri = "https://github.com/tpruvot/cpuminer-multi/releases/download/v1.3.1-multi/cpuminer-multi-rel1.3.1-x64.zip"
$Port = "510{0:d2}"

$Devices = $Devices.CPU
if (-not $Devices -or $Config.InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject]@{
    # CPU Only algos 3/27/2018
    "yescrypt" = "" #Yescrypt
    #"axiom" = "" #axiom
    
    # CPU & GPU - still profitable 27/03/2018
    "cryptonight" = "" #CryptoNight
    "hmq1725" = "" #HMQ1725
    "shavite3" = "" #shavite3

    #GPU - never profitable 27/03/2018
    #"bastion" = "" #bastion
    #"bitcore" = "" #Bitcore
    #"blake" = "" #blake
    #"blake2s" = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"bmw" = "" #bmw
    #"c11" = "" #C11
    #"cryptolight" = "" #cryptolight
    #"decred" = "" #Decred
    #"dmd-gr" = "" #dmd-gr
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = "" #Groestl
    #"jha" = "" #JHA
    #"keccak" = "" #Keccak
    #"keccakc" = "" #keccakc
    #"lbry" = "" #Lbry
    #"lyra2re" = "" #lyra2re
    #"lyra2v2" = "" #Lyra2RE2
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = "" #Nist5
    #"pascal" = "" #Pascal
    #"pentablake" = "" #pentablake
    #"pluck" = "" #pluck
    #"scrypt:N" = "" #scrypt:N
    #"scryptjane:nf" = "" #scryptjane:nf
    #"sha256d" = "" #sha256d
    #"sib" = "" #Sib
    #"skein" = "" #Skein
    #"skein2" = "" #skein2
    #"skunk" = "" #Skunk
    #"timetravel" = "" #Timetravel
    #"tribus" = "" #Tribus
    #"vanilla" = "" #BlakeVanilla
    #"veltor" = "" #Veltor
    #"x11" = "" #X11
    #"x11evo" = "" #X11evo
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
    #"x16r" = "" #x16r
    #"zr5" = "" #zr5
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-b $($Miner_Port) -a $_ -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"
            HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $Stats."$($Miner_Name)_$(Get-Algorithm $_)_HashRate".Week}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
        }
    }
}