using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
$Uri = "http://www.gandalph3000.com/download/cast_xmr-vega-win64_130.zip"
$Port = "306{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonightfast"; Params = "--algo=8 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightheavy"; Params = "--algo=2 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightlite"; Params = "--algo=3 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonighttubeheavy"; Params = "--algo=5 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = "--algo=1 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7lite"; Params = "--algo=4 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7stellitev4"; Params = "--algo=6 --intensity=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightxhvheavy"; Params = "--algo=7 --intensity=8"}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ','

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path      = $Path
            Arguments = "--remoteaccess --remoteport $($Miner_Port) -S $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --forcecompute --fastjobswitch -G $($DeviceIDsAll) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API       = "Cast"
            Port      = $Miner_Port
            URI       = $Uri
            DevFee    = 1.5
        }
    }
}