using module ..\Include.psm1

$Path = ".\Bin\Equihash-EWBF\miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3-ewbf/EWBF.Equihash.miner.v0.3.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "EquihashBTG"; Params = "--algo 144_5 --pers BgoldPoW"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Minexcoin"; Params = "--algo 95_5"} #Equihash 95,5
    [PSCustomObject]@{MainAlgorithm = "Zerocoin"; Params = "--algo 192_7 --pers ZERO_PoW"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Zhash"; Params = "--algo zhash"} #Zhash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model    

    $DeviceIDsAll = Get-GPUIDs $Miner_Device -join ' '

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Miner_Name = (@($Name) + @($_.MainAlgorithm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "--api 127.0.0.1:$($Miner_Port) --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
            API = "DSTM"
            Port = $Miner_Port
            DevFee = 0
            URI = $URI
        }
    }
}