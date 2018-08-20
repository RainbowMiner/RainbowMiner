using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\NVIDIA-Trex\t-rex.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.1-trex/t-rex-0.6.1-win-cuda9.1.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$Port = "316{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "hsr"; Params = ""} #HSR
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = ""} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = ""} #PHI
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "renesis"; Params = ""} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = ""} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = ""} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = ""; ExtendInterval = 4; FaultTolerance = 0.5} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""; FaultTolerance = 0.5} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = ""} #X17
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
                Arguments = "-b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
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