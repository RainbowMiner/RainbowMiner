using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Ethash-Eminer\eminer.exe"
$Uri = "https://github.com/ethash/eminer-release/releases/download/v0.6.1-rc2/eminer.v0.6.1-rc2.win64.zip"
$ManualUri = "https://github.com/ethash/eminer-release"
$Port = "318{0:d2}"
$DevFee = 0.0
$Cuda = "6.5"

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    #[PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    #[PSCustomObject]@{MainAlgorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)
$CommonCommands = " -no-devfee"

# Set devfee default coin, it may reduce DAG changes
$DevFeeCoin  = [PSCustomObject]@{
    "ETH" = " -devfee-coin ETH"
    "ETC" = "-devfee-coin ETC"
    "EXP" = " -devfee-coin EXP"
    "MUSIC" = " -devfee-coin MUSIC"
    "UBQ" = " -devfee-coin UBQ"
}

$Name = "$(Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName)"

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

if (-not (Confirm-Cuda $Cuda $Name)) {return}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = @($Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model)
    $Miner_Model = $_.Model

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm = $_.MainAlgorithm
        $Algorithm_Norm = Get-Algorithm $Algorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1Gb})) {            
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

            $Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"
            $DeviceIDsAll = ($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Mineable_Index)}) -join ','

            [PSCustomObject]@{
                Name                 = $Miner_Name
                DeviceName           = $Miner_Device.Name
                DeviceModel          = $Miner_Model
                Path                 = $Path
                Arguments            = "-http :$Miner_Port -S $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -U $($Pools.$Algorithm_Norm.User) -P $($Pools.$Algorithm_Norm.Pass)$(if($Config.WorkerName) {" -N $($Config.WorkerName)"})$(if($DevfeeCoin.($Pools.$Algorithm_Norm.CoinSymbol)) {"$($DevfeeCoin.($Pools.$Algorithm_Norm.CoinSymbol))"})$($Commands.$_)$CommonCommands -M $($DeviceIDsAll)"
                HashRates            = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API                  = "Eminer"
                Port                 = $Miner_Port
                URI                  = $Uri
                DevFee               = $DevFee
                ManualUri            = $ManualUri
            }
        }
    }
}