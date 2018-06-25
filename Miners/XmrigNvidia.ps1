using module ..\Include.psm1

$Path = ".\Bin\CryptoNight-NVIDIA\xmrig-nvidia.exe"
$Uri = "https://github.com/xmrig/xmrig-nvidia/releases/download/v2.6.1/xmrig-nvidia-2.6.1-cuda9-win64.zip"
$Port = "303{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy"; Params = ""}
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

        $xmrig_algo = if ($_.MainAlgorithm -eq "cryptonightv7") {"cryptonight"} else {$_.MainAlgorithm}
        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path      = $Path
            Arguments = "-R 1 --cuda-devices=$($DeviceIDsAll) --api-port $($Miner_Port) -a $($xmrig_algo) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --keepalive --nicehash --donate-level=1 $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API       = "XMRig"
            Port      = $Miner_Port
            URI       = $Uri
            DevFee    = 1.0
        }
    }
}