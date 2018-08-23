using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Equihash-EWBF\miner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.5-ewbf/EWBF.Equihash.miner.v0.5.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash965";  MinMemGB = 2.5; Params = "--algo 96_5"}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1445"; MinMemGB = 2; Params = "--algo 144_5"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1927"; MinMemGB = 2.5; Params = "--algo 192_7"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash2109"; MinMemGB = 0.5; Params = "--algo 210_9"} #Equihash 210,9 (beta)
)

$Coins = [PSCustomObject]@{
    default     = ""
    AION        = "--pers AION0PoW"
    BTG         = "--pers BgoldPoW"
    BTCZ        = "--pers BitcoinZ"
    SAFE        = "--pers Safecoin"
    XSG         = "--pers sngemPoW"
    ZEL         = "--pers ZelProof"
    ZER         = "--pers ZERO_PoW"
}

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    @($Coins.PSObject.Properties.Name) | Foreach-Object {
        $Miner_Coin = $_

        $Commands | ForEach-Object {
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            if ($Miner_Coin -ne "default") {$Algorithm_Norm = "$Algorithm_Norm-$Miner_Coin"}

            #ZergPool introduces auto switching for Equihash144: https://bitcointalk.org/index.php?topic=2759935.msg43324268#msg43324268
            if (@("Equihash24x5","Equihash24x7") -icontains ($Algorithm_Norm -replace '\-.*$') -and $Pools.$Algorithm_Norm.Name -like "ZergPool*") {$MinerCoin_Params = "--pers auto"}
            else {
                $MinerCoin_Params = if ($Pools.$Algorithm_Norm.CoinSymbol) {$Coins."$($Pools.$Algorithm_Norm.CoinSymbol)"} else {$Coins."$($Pools.$Algorithm_Norm.CoinName)"}
            }

            $MinMemGB = $_.MinMemGB        
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'            

            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '
        
            if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "--api 127.0.0.1:$($Miner_Port) --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User) --pass $($Pools.$Algorithm_Norm.Pass) $($MinerCoin_Params) $($_.Params)"
                    HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
                    API = "DSTM"
                    Port = $Miner_Port
                    DevFee = 0
                    URI = $URI
                    ExtendInterval = 2
                    ManualUri = $ManualUri
                }
            }
        }
    }
}