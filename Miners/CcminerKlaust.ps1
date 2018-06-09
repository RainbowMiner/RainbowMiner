using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
#$Uri = "https://github.com/KlausT/ccminer/releases/download/8.21/ccminer-821-cuda91-x64.zip"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21k-ccminerklaust/ccminerklaust_v8.21k.7z"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #GPU - profitable 20/04/2018
    #"c11" = "" #C11
    #"deep" = "" #deep
    #"dmd-gr" = "" #dmd-gr
    #"fresh" = "" #fresh
    #"fugue256" = "" #Fugue256
    #"groestl" = "" #Groestl
    #"jackpot" = "" #Jackpot
    #"keccak" = "" #Keccak
    #"luffa" = "" #Luffa
    #"lyra2v2" = "" #Lyra2RE2
    #"lyra2z" = " -N 1" #lyra2z
    "neoscrypt" = " -N 1" #NeoScrypt
    #"penta" = "" #Pentablake
    #"skein" = "" #Skein
    #"s3" = "" #S3
    #"tribus" = "" #Tribus
    #"veltor" = "" #Veltor
    #"whirlpool" = "" #Whirlpool
    #"whirlpoolx" = "" #whirlpoolx
    #"X17" = "" #X17 Verge
    "yescrypt" = " -N 1" #yescrypt
    "yescryptR8" = " -N 1"
    "yescryptR16" = " -N 1" #YescryptR16 #Yenten
    "yescryptR16v2" = " -N 1" #PPN

    # ASIC - never profitable 20/04/2018
    #"blake" = "" #blake
    #"blakecoin" = "" #Blakecoin
    #"blake2s" = "" #Blake2s
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"quark" = "" #Quark
    #"qubit" = "" #Qubit
    #"vanilla" = "" #BlakeVanilla
    #"sha256d" = "" #sha256d
    #"sia" = "" #SiaCoin
    #"x11" = "" #X11
    #"x13" = "" #x13
    #"x14" = "" #x14
    #"x15" = "" #x15
}

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "lyra2v2" = 4
    "lyra2z" = 4
    "neoscrypt" = 3
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUIDs $Devices -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        DeviceName = $Devices.Name
        Path = $Path
        Arguments = "-r 0 -R 5 -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -b 4068$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
        BenchmarkIntervals = 2
    }
}