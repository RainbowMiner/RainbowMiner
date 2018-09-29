using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\Equihash-Claymore\ZecMiner64.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v12.6-claymoreequihash/claymore_equihash_v12.6.zip"
$Port = "201{0:d2}"
$ManualURI = "https://bitcointalk.org/index.php?topic=1670733.0"
$DevFee = 2.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""} #Equihash
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
                Arguments = "-r -1 -mport -$($Miner_Port) -zpool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -zwal $($Pools.$Algorithm_Norm.User) -zpsw $($Pools.$Algorithm_Norm.Pass) -allpools 1 -di $($DeviceIDsAll) -logfile $($Miner_Port)_log.txt $($_.Params)"
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