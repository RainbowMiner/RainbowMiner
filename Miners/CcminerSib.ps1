using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Sib\ccminer_x11gost.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-ccminersib/ccminer_x11gost_1.0.7z"

$Type = "NVIDIA"
if (-not $Devices.$Type -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "blake2s"   = "" #Blake2s
    "blakecoin" = "" #Blakecoin
    #"c11"       = "" #C11 (alexis78 is fastest)
    #"keccak"    = "" #Keccak (alexis78 is fastest)
    #"lyra2v2"   = "" #Lyra2RE2 (alexis78 is fastest)
    #"neoscrypt" = "" #NeoScrypt (excavator is fastest)
    "sib"       = "" #Sib
    #"skein"     = "" #Skein (alexis78 is fastest)
    "x11evo"    = "" #X11evo

    # ASIC - never profitable 12/05/2018
    #"decred" = "" #Decred
    #"lbry" = "" #Lbry
    #"myr-gr" = "" #MyriadGroestl
    #"nist5" = "" #Nist5
    #"sib" = "" #Sib
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
        PrerequisitePath = "$env:SystemRoot\System32\msvcr120.dll"
        PrerequisiteURI = "http://download.microsoft.com/download/2/E/6/2E61CFA4-993B-4DD4-91DA-3737CD5CD6E3/vcredist_x64.exe"
    }
}