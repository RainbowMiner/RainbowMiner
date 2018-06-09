using module ..\Include.psm1

$Path = ".\Bin\Ethash-Phoenix\PhoenixMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.9e-phoenixminer/PhoenixMiner_2.9e.zip"

$Devices = Select-Device $Devices "NVIDIA"
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA/AMD present in system

$Commands = [PSCustomObject]@{
    "ethash" = " -mi 12" #Ethash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices3gb = Select-Device $Devices -MinMemSize 3gb

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $possum    = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "-proto 4 -stales 0" } else { "-proto 1" }
    $proto     = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "stratum+tcp://" } else { "" }
    $possum2gb = if ( $Pools."$($Algorithm_Norm)2gb".Protocol -eq "stratum+tcp" <#temp fix#> ) { "-proto 4 -stales 0" } else { "-proto 1" }
    $proto2gb  = if ( $Pools."$($Algorithm_Norm)2gb".Protocol -eq "stratum+tcp" <#temp fix#> ) { "stratum+tcp://" } else { "" }

    if ( $Devices3gb ) {
        [PSCustomObject]@{
            Device = $Devices3gb
            Path = $Path
            Arguments = "-rmode 0 -cdmport 23334 -cdm 1 -coin auto -gpus $(Get-GPUIDs $Devices3gb -Join '' -Offset 1) -pool $($proto)$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass) $($possum) -nvidia$($Commands.$_)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "Claymore"
            Port = 23334
            URI = $Uri
            DevFee = 0.65
            MSIAprofile = 2
        }
    }
    [PSCustomObject]@{
        Type = $Type
        Path = $Path
        Arguments = "-rmode 0 -cdmport 23334 -cdm 1 -coin auto -gpus $(Get-GPUIDs $Devices -Join '' -Offset 1) -pool $($proto2gb)$($Pools."$($Algorithm_Norm)2gb".Host):$($Pools."$($Algorithm_Norm)2gb".Port) -wal $($Pools."$($Algorithm_Norm)2gb".User) -pass $($Pools."$($Algorithm_Norm)2gb".Pass)  $($possum2gb) -nvidia$($Commands.$_)"
        HashRates = [PSCustomObject]@{"$($Algorithm_Norm)2gb" = $($Stats."$($Name)_$($Algorithm_Norm)2gb_HashRate".Week)}
        API = "Claymore"
        Port = 23334
        URI = $Uri
        DevFee = 0.65
        MSIAprofile = 2
    }
}