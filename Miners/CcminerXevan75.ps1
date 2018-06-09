using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Xevan75\ccminer.exe"
$Uri = "https://github.com/nemosminer/ccminer-xevan/releases/download/Alexis78xevan/ccminerAlexis78Xevan.7z"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    #"c11" = " -N 1 -i 21" #c11
    #"keccak"    = "" #Keccak
    #"lyra2v2"   = " -N 1" #Lyra2RE2 (alexis78 is faster)
    "skein"     = " -N 1" #Skein
    "xevan"     = " -N 1" #Xevan
    
    # ASIC - never profitable 12/05/2018
    #"blake2s"   = "" #Blake2s
    #"blakecoin" = "" #Blakecoin
    #"decred"   = "" #Decred
    #"lbry"     = "" #Lbry
    #"myr-gr"   = "" #MyriadGroestl
    #"nist5"    = "" #Nist5
    #"qubit"    = "" #Qubit
    #"quark"    = "" #Quark
    #"x12"      = "" #X12
    #"x14"      = "" #X14
}

$Default_Profile = 2
$Profiles = [PSCustomObject]@{
    "lyra2v2" = 4
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUIDs $Devices -join ','

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        DeviceName = $Devices.Name
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        URI = $Uri
        MSIAprofile = if ( $Profiles.$_ ) { $Profiles.$_ } else { $Default_Profile }
    }
}