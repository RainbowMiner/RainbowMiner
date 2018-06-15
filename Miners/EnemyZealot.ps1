using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.11-enemyzealot/z-enemy.1-11-public-final_v3.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "302{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "aeriumx"    = " -N 1" #AeriumX, new in 1.11
    "bitcore"    = " -N 1" #Bitcore
    "c11"        = " -N 1" # New in 1.11
    "phi"        = " -N 1" #PHI
    "polytimos"  = " -N 1" #Polytimos
    "skunk"      = " -N 1" #Skunk, new in 1.11
    "timetravel" = " -N 1" #Timetravel8
    "tribus"     = " -N 1" #Tribus, new in 1.10
    #"x16r"       = " -N 100" #Raven, Ravencoin-Miner 3.0 is faster 
    "x16s"       = "" #Pigeon
    "x17"        = " -N 1" #X17
    "xevan"      = " -N 1" #Xevan, new in 1.09a
    "vit"        = " -N 1" #Vitality, new in 1.09a
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
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $_ -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass)$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".$HashRates_Duration}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = if ( $Tolerances.$_ ) { $Tolerances.$_ } else { $Default_Tolerance }
            DevFee = 1.0
        }
    }
}