using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Equihash-lolMiner\lolMiner.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.43b-lolminer/lolMiner_v043b_Win64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4724735.0"
$Port = "317{0:d2}"
$DevFee = 2.0

$Devices = @($Devices.NVIDIA) + @($Devices.AMD)
if (-not $Devices -and -not $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "Equihash16x5"; Coin = "MNX";   WorkBatch = "MEDIUM"; MinMemGB = 6; Params = "-workbatch=MEDIUM"; Fee=1}  #Equihash 96,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash16x5"; Coin = "MNX";   WorkBatch = "HIGH"; MinMemGB = 6; Params = "-workbatch=HIGH"; Fee=1}  #Equihash 96,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash16x5"; Coin = "MNX";   WorkBatch = "VERYHIGH"; MinMemGB = 6; Params = "-workbatch=VERYHIGH"; Fee=1}  #Equihash 96,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "";      WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "ASF";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "BCRM";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "BTCZ";  WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "BTG";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "CDY";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "HEPTA"; WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "LTZ";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "SAFE";  WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x5"; Coin = "XSG";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x7"; Coin = "GENX"; WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
    #[PSCustomObject]@{MainAlgorithm = "Equihash24x7"; Coin = "ZER";   WorkBatch = ""; MinMemGB = 4; Params = ""; Fee=2} #Equihash 144,5
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$UserConfig = [hashtable]@{
    DEFAULTS = [hashtable]@{
        DIGITS = 2
        CONNECTION_ATTEMPTS = 4
        RECONNECTION_TIMER = 5
    }
}

$Miner_Algorithms_Norm = [hashtable]@{}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        if (-not $Miner_Algorithms_Norm.ContainsKey($_.MainAlgorithm)) {$Miner_Algorithms_Norm[$_.MainAlgorithm] = Get-Algorithm $_.MainAlgorithm}
        $Algorithm_Norm = $Miner_Algorithms_Norm[$_.MainAlgorithm]
        $Miner_Coin = $_.Coin
        $Miner_Fee = $_.Fee
        $Miner_WorkBatch = $_.WorkBatch
        if ($Miner_Coin -ne "") {$Algorithm_Norm="$Algorithm_Norm-$Miner_Coin"}

        if ($Pools.$Algorithm_Norm.Host) {
            if (@("Equihash24x5") -icontains ($Algorithm_Norm -replace '\-.*$') -and $Pools.$Algorithm_Norm.Name -like "ZergPool*") {$Miner_Coin = "AUTO144"}

            $MinMemGB = $_.MinMemGB
            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb)}
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
            $Miner_Name = (@($Name) + @($_.WorkBatch | Select-Object) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-' -replace '-+','-'            

            if ($Miner_Device) {
                $UserConfig_Name = $Algorithm_Norm.ToUpper() -replace '-','_'
                $UserConfig.$UserConfig_Name = [hashtable]@{
                    COIN    = $Miner_Coin
                    APIPORT = $Miner_Port
                    DEVICES = $Miner_Device.Type_Vendor_Index
                    DISABLE_MEMCHECK = if ($Miner_Device | Where-Object {$_.OpenCL.GlobalMemsize -le 4gb}){1}else{0}
                    POOLS   = @(
                        [hashtable]@{
                            POOL = $Pools.$Algorithm_Norm.Host
                            PORT = "$($Pools.$Algorithm_Norm.Port)"
                            USER = $Pools.$Algorithm_Norm.User
                            PASS = $Pools.$Algorithm_Norm.Pass
                        }
                    )
                }
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "-profile=$($UserConfig_Name) $($_.Params)"
                    HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week)}
                    API = "Lol"
                    Port = $Miner_Port
                    DevFee = $Miner_Fee
                    Uri = $Uri
                    ExtendInterval = 1
                    ManualUri = $ManualUri
                }
            }
        }
    }
}

if ($UserConfig.Count -gt 1) {
    $UserConfig | ConvertTo-Json -Depth 10 | Set-Content "$(Split-Path $Path)\user_config.json" -Force -ErrorAction SilentlyContinue
}