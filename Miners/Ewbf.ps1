using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Equihash-EWBF\miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3-ewbf/EWBF.Equihash.miner.v0.3.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash144"; Params = "--algo 144_5"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash192"; Params = "--algo 192_7"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash96"; Params = "--algo 96_5"} #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Zhash"; Params = "--algo zhash"} #Equihash 144,5 Zhash/BitcoinZ
)

$Coins = [PSCustomObject]@{
    BitcoinGold = "--pers BgoldPoW"
    BTG = "--pers BgoldPow"
    Snowgem = "--pers sngemPoW"
    Zero = "--pers ZERO_PoW"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model    

    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ' '

    $Commands | ForEach-Object {
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinerCoin_Params = $Coins."$($Pools.$Algorithm_Norm.CoinName)"

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api 127.0.0.1:$($Miner_Port) --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) $($MinerCoin_Params) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "DSTM"
                Port = $Miner_Port
                DevFee = 0
                URI = $URI
            }
        }
    }
}