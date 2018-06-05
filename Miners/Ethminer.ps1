using module ..\Include.psm1

$Path = ".\Bin\Ethash-Ethminer\ethminer.exe"
$URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.15.0.dev11/ethminer-0.15.0.dev11-Windows.zip"

$Commands = [PSCustomObject]@{
    "ethash" = "" #Ethash
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Devices.NVIDIA -and -not $Config.InfoOnly) {
    $Device = $Devices.NVIDIA
    $Device3gb = Select-Device $Device -MinMemSize 3GB

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        $proto = $Pools.$Algorithm_Norm.Protocol -replace "stratum","stratum$(if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash'){2})"
        $proto2g = $Pools."$($Algorithm_Norm)2g".Protocol -replace "stratum","stratum$(if ($Pools."$($Algorithm_Norm)2g".Name -eq 'NiceHash' ){2})"
        $Miner_Name = "$($Name)Nvidia"

        if ( $Device3gb ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Device3gb.Name
                Path = $Path
                Arguments = "--api-port 23333 --cuda-devices $(Get-GPUIDs $Device3gb -join ' ') -P $($proto)://$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cuda$($Commands.$_)"            
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Claymore"
                Port = 23333
                URI = $Uri
            }
        }
        [PSCustomObject]@{
            Name = "$($Name)Nvidia"
            DeviceName = $Device.Name
            Path = $Path
            Arguments = "--api-port 23333 --cuda-devices $(Get-GPUIDs $Device -join ' ') -P $($proto2g)://$($Pools."$($Algorithm_Norm)2gb".User):$($Pools."$($Algorithm_Norm)2gb".Pass)@$($Pools."$($Algorithm_Norm)2gb".Host):$($Pools."$($Algorithm_Norm)2gb".Port) --cuda$($Commands.$_)"            
            HashRates = [PSCustomObject]@{"$($Algorithm_Norm)2gb" = $Stats."$($Miner_Name)_$($Algorithm_Norm)2gb_HashRate".Week}
            API = "Claymore"
            Port = 23333
            URI = $Uri
        }     
    }
}

if ($Devices.AMD -and -not $Config.InfoOnly) {
    $Device = $Devices.AMD
    $Device3gb = Select-Device $Device -MinMemSize 3GB

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_

        $proto = $Pools.$Algorithm_Norm.Protocol -replace "stratum","stratum$(if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash'){2})"
        $proto2g = $Pools."$($Algorithm_Norm)2g".Protocol -replace "stratum","stratum$(if ($Pools."$($Algorithm_Norm)2g".Name -eq 'NiceHash' ){2})"

        $Miner_Name = "$($Name)Amd"

        if ( $Device3gb ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Device3gb.Name
                Path = $Path
                Arguments = "--api-port 23333 --opencl-devices $(Get-GPUIDs $Device3gb -join ' ') -P $($proto)://$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --opencl --opencl-platform $($Device3gb | select -Property Platformid -Unique -ExpandProperty PlatformId)$($Commands.$_)"            
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Claymore"
                Port = 23333
                URI = $Uri
            }
        }
        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Device.Name
            Path = $Path
            Arguments = "--api-port 23333 --opencl-devices $(Get-GPUIDs $Device -join ' ') -P $($proto2g)://$($Pools."$($Algorithm_Norm)2gb".User):$($Pools."$($Algorithm_Norm)2gb".Pass)@$($Pools."$($Algorithm_Norm)2gb".Host):$($Pools."$($Algorithm_Norm)2gb".Port) --opencl --opencl-platform $($Device | select -Property Platformid -Unique -ExpandProperty PlatformId)$($Commands.$_)"            
            HashRates = [PSCustomObject]@{"$($Algorithm_Norm)2gb" = $Stats."$($Miner_Name)_$($Algorithm_Norm)2gb_HashRate".Week}
            API = "Claymore"
            Port = 23333
            URI = $Uri
        }     
    }
}