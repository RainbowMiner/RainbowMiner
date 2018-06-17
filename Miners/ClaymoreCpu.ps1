using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-Claymore-Cpu\NsCpuCNMiner64.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0-claymorecpu/claymore_cryptonight_cpu_4.0.zip"
$Port = "520{0:d2}"

$Devices = $Devices.CPU
if (-not $Devices -or $Config.InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject]@{
    "cryptonight" = "" #CryptoNight
    "cryptonightv7" = "" #CryptoNightV7
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {$Pools.(Get-Algorithm $_).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {
        if ( $_ -eq "cryptonight" ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r -1 -mport $($Miner_Port) -pow7 0 -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"            
                HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $($Stats."$($Miner_Name)_$(Get-Algorithm $_)_HashRate".Week)}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
            }
        } elseif ( $_ -eq "cryptonightv7" ) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r -1 -mport $($Miner_Port) -pow7 1 -o $($Pools.(Get-Algorithm $_).Protocol)://$($Pools.(Get-Algorithm $_).Host):$($Pools.(Get-Algorithm $_).Port) -u $($Pools.(Get-Algorithm $_).User) -p $($Pools.(Get-Algorithm $_).Pass)$($Commands.$_)"            
                HashRates = [PSCustomObject]@{(Get-Algorithm $_) = $($Stats."$($Miner_Name)_$(Get-Algorithm $_)_HashRate".Week)}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
            }
        }
    }
}