using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-CcminerCool\coolMiner-x64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1-ccminercool/coolMiner-x64-v1-1.7z"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject]@{
    "lyra2z" = " -N 1" #Lyra2z
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$DeviceIDsAll = Get-GPUIDs $Devices -join ','

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {

    $Algorithm_Norm = Get-Algorithm $_

    [PSCustomObject]@{
        DeviceName = $Devices.Name
        Path = $Path
        Arguments = "-r 0 -d $($DeviceIDsAll) -b 4068 -a $_ -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --submit-stale$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
        DevFee = 1.0
    }
}