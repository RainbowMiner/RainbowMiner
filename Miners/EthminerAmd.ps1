using module ..\Include.psm1

$Path = ".\Bin\Ethash-Ethminer\ethminer.exe"
$URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.15.0.dev10/ethminer-0.15.0.dev10-Windows.zip"

$Commands = [PSCustomObject]@{
    "ethash" = "" #Ethash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$DeviceIDsAll = Get-GPUlist "AMD"
$DeviceIDs3gb = Get-GPUlist "AMD" 3GB

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

    $Algorithm_Norm = Get-Algorithm $_

    $proto = $Pools.$Algorithm_Norm.Protocol -replace "stratum","stratum$(if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash'){2})"
    $proto2g = $Pools."$($Algorithm_Norm)2g".Protocol -replace "stratum","stratum$(if ($Pools."$($Algorithm_Norm)2g".Name -eq 'NiceHash' ){2})"
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-port 23333 --cuda-devices $($DeviceIDs3gb -join ' ') -P $($proto)://$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cuda$($Commands.$_)"            
        HashRates = [PSCustomObject]@{$Algorithm_Norm = $( if ($DeviceIDs3gb) { $Stats."$($Name)_$($Algorithm_Norm)_HashRate".Week } else { 0 })}
        API = "Claymore"
        Port = 23333
        URI = $Uri
    },
    [PSCustomObject]@{
        Type = "AMD"
        Path = $Path
        Arguments = "--api-port 23333 --cuda-devices $($DeviceIDsAll -join ' ') -P $($proto2g)://$($Pools."$($Algorithm_Norm)2gb".User):$($Pools."$($Algorithm_Norm)2gb".Pass)@$($Pools."$($Algorithm_Norm)2gb".Host):$($Pools."$($Algorithm_Norm)2gb".Port) --cuda$($Commands.$_)"            
        HashRates = [PSCustomObject]@{"$($Algorithm_Norm)2gb" = $($Stats."$($Name)_$($Algorithm_Norm)2gb_HashRate".Week)}
        API = "Claymore"
        Port = 23333
        URI = $Uri
    }     
}