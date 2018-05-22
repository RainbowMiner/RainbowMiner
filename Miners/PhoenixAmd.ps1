using module ..\Include.psm1

$Path = ".\Bin\Ethash-Phoenix\PhoenixMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.9e-phoenixminer/PhoenixMiner_2.9e.zip"

$Commands = [PSCustomObject]@{
    "ethash" = "" #Ethash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $possum    = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "-proto 4 -stales 0" } else { "-proto 1" }
    $proto     = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "stratum+tcp://" } else { "" }
    $possum2gb = if ( $Pools."$($Algorithm_Norm)2gb".Protocol -eq "stratum+tcp" <#temp fix#> ) { "-proto 4 -stales 0" } else { "-proto 1" }
    $proto2gb  = if ( $Pools."$($Algorithm_Norm)2gb".Protocol -eq "stratum+tcp" <#temp fix#> ) { "stratum+tcp://" } else { "" }


    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "-rmode 0 -cdmport 23335 -cdm 1 -coin auto -gpus $((Get-GPUlist "AMD" 3GB 1) -join '') -pool $($proto)$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass) $($possum) -amd$($Commands.$_)"
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $(if (Get-GPUlist "AMD" 3GB) { $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week } else { 0 })}
        API = "Claymore"
        Port = 23335
        URI = $Uri
        DevFee = 0.65
    },
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "-rmode 0 -cdmport 23335 -cdm 1 -coin auto -gpus $((Get-GPUlist "AMD" 0GB 1) -join '') -pool $($proto2gb)$($Pools."$($Algorithm_Norm)2gb".Host):$($Pools."$($Algorithm_Norm)2gb".Port) -wal $($Pools."$($Algorithm_Norm)2gb".User) -pass $($Pools."$($Algorithm_Norm)2gb".Pass)  $($possum2gb) -amd$($Commands.$_)"
        HashRates = [PSCustomObject]@{"$($Algorithm_Norm)2gb" = $(if (Get-GPUlist "AMD") { $Stats."$($Name)_$($Algorithm_Norm)2gb_HashRate".Week } else { 0 })}
        API = "Claymore"
        Port = 23335
        URI = $Uri
        DevFee = 0.65
    }
}