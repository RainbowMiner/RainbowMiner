using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.16-enemyzealot/z-enemy.1-16-cuda9.2_x64.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "302{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-N 1"} #AeriumX, new in 1.11
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = "-N 1"} #Bitcore
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"} # New in 1.11
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = "-N 1"; ExtendInterval = 2; FaultTolerance = 0.5} #HEX/XDNA, new in 1.15a
    [PSCustomObject]@{MainAlgorithm = "hsr"; Params = "-N 1"} #HSR
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = "-N 1"; ExtendInterval = 2} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = "-N 1"} #PHI2, new in 1.12
    [PSCustomObject]@{MainAlgorithm = "poly"; Params = "-N 1"} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "renesis"; Params = "-N 1"} #Renesis
    #[PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-N 1"} #Skunk, new in 1.11
    #[PSCustomObject]@{MainAlgorithm = "sonoa"; Params = "-N 1"} #Sonoa, new in 1.12 (T-rex fastest)
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "-N 1"} #Timetravel8
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-N 1"} #Tribus, new in 1.10
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 10"; ExtendInterval = 4; FaultTolerance = 0.5; HashrateDuration = "Day"} #X16R (T-rex fastest)
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-N 3"; FaultTolerance = 0.5} #X16S
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "-N 1"} #X17
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-N 1"} #Xevan, new in 1.09a
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {        
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                API = "Ccminer"
                Port = $Miner_Port
                URI = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = 1.0
                ManualUri = $ManualUri
            }
        }
    }
}