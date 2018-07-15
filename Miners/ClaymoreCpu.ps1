using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-Claymore-Cpu\NsCpuCNMiner64.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v4.0-claymorecpu/claymore_cryptonight_cpu_4.0.zip"
$Port = "520{0:d2}"

$Devices = $Devices.CPU
if (-not $Devices -or $Config.InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = "-pow7 0"} #CryptoNight
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = "-pow7 1"} #CryptoNightV7
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r -1 -mport $($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"            
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
            }
        }
    }
}