using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-Ravencoin\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.0-ravencoinminer/ccminerRavenx32.zip"
$Port = "107{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "x16r"  = " -N 10 --donate 0" #X16R RavenCoin
    #"x16s"  = "" #X16S PigeonCoin
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
            DevFee = 0.0
        }
    }
}