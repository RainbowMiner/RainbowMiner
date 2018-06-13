using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.11-enemyzealot/z-enemy.1-11-public-final_v3.7z"
$Port = "302{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "aeriumx" = " -N 1" #Aolytimos
    "bitcore" = " -N 1" #Bitcore(sp-mod faster)
    #"blake2s" = " --api-remote --api-allow=0/0" #Blake2s
    #"blakecoin" = "" #Blakecoin
    "c11" = " -N 1" #C11
    #"cryptonight" = " -i 10" #Cryptonight
    #"decred" = "" #Decred
    #"equihash" = "" #Equihash
    #"ethash" = "" #Ethash
    #"groestl" = " --api-remote --api-allow=0/0" #Groestl
    #"hmq1725" = "" #hmq1725
    #"hsr" = " --api-remote --api-allow=0/0" #Hsr
    #"keccakc" = " --api-remote --api-allow=0/0" #Keccakc
    #"lbry" = " --api-remote --api-allow=0/0" #Lbry
    #"lyra2v2" = " -N 1 --api-remote --api-allow=0/0" #Lyra2RE2
    #"lyra2z" = "  --api-remote --api-allow=0/0 --submit-stale" #Lyra2z
    #"myr-gr" = "" #MyriadGroestl
    #"neoscrypt" = "" #NeoScrypt
    #"nist5" = " --api-remote --api-allow=0/0" #Nist5
    #"pascal" = "" #Pascal
    "phi" = " -N 1" #Phi(sp-mod faster)
    "polytimos" = " -N 1" #Polytimos
    #"qubit" = "" #Qubit
    #"scrypt" = "" #Scrypt
    #"sha256t" = "" #Sha256t
    #"sia" = "" #Sia
    #"sib" = " --api-remote --api-allow=0/0" #Sib
    #"skein" = "" #Skein
    "skunk" = " -N 1" #Skunk
    "timetravel" = " -N 1" #Timetravel
    "tribus" = " -N 1" #Tribus
    "xevan" = " -N 1" #Xevan
    #"x11evo" = "" #X11evo
    #"x16r" = " -i 20" #X16r(sp-hash faster/very close)
    #"x16s" = "" #X16s(CcminerPigencoin is faster)
    "x17" = " -N 1" #X17(Alexis78 and enemy 1.03 faster)
    #"vanilla" = "" #BlakeVanilla
    "vitalium" = " -N 3" #Vitalium
    #"yescrypt" = "" #Yescrypt
}

$Default_Tolerance = 0.1
$Tolerances = [PSCustomObject]@{
    "x16r" = 0.5
}

$Default_HashRates_Duration = "Week"
$HashRates_Durations = [PSCustomObject]@{
    "x16r" = "Day"
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
        $HashRates_Duration = if ( $HashRates_Durations.$_ ) { $HashRates_Durations.$_ } else { $Default_HashRates_Duration }

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-r 0 -b $($Miner_Port) -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".$HashRates_Duration}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = if ( $Tolerances.$_ ) { $Tolerances.$_ } else { $Default_Tolerance }
            DevFee = 1.0
        }
    }
}