using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Polytimos\ccminer.exe"
#$URI = "https://github.com/punxsutawneyphil/ccminer/releases/download/polytimosv2/ccminer-polytimos_v2.zip"
#$URI = "https://github.com/nemosminer/ccminerpolytimos/releases/download/Alexis78-1.0/ccminer-polytimos.7z"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-ccminerpolytimos/ccminerpolytimos_1.0.zip"

$Commands = [PSCustomObject]@{
    #"hsr"       = "" #HSR
    #"keccak"    = "" #Keccak
    #"lyra2v2"   = "" #Lyra2RE2 (alexis78 faster)
    "poly"      = "" #Polytimos
    #"skein"     = "" #Skein
    "veltor"    = " -i 23" #Veltor
    "x11evo"    = "" #X11evo

    # ASIC - never profitable 12/05/2018
    #"blake2s"   = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"decred"   = "" #Decred
    #"lbry"     = "" #Lbry
    #"myr-gr"   = "" #MyriadGroestl
    #"nist5"    = "" #Nist5
    #"qubit"    = "" #qubit
    #"quark"    = "" #Quark
    #"x12"      = "" #X12
    #"x14"      = "" #X14
}

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "lyra2v2" = 4
    "nist5"   = 4
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUlist "NVIDIA"

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll -join ',') -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
    }
}