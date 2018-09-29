using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\CryptoNight-Claymore\NsGpuCNMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v11.3-claymorecryptonight/claymore_cryptonight_11.3.zip"
$Port = "200{0:d2}"
$ManualURI = "https://bitcointalk.org/index.php?topic=638915.0"
$DevFee = 0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptolite"; Params = " -lite 1 0"} #Cryptolite
    [PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = " -pow7 0"} #CryptoNight
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = " -pow7 1"} #CryptoNightV7
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
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

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f $_.Type_Vendor_Index} ) -join ''

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r -1 -mport -$($Miner_Port) -xpool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -xwal $($Pools.$Algorithm_Norm.User) -xpsw $($Pools.$Algorithm_Norm.Pass) -di $($DeviceIDsAll) -logfile $($Miner_Port)_log.txt $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API = "Claymore"
                Port = $Miner_Port
                Uri = $Uri
				DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}