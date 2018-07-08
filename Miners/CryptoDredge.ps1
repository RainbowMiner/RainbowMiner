using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$Uri = "https://github.com/technobyl/CryptoDredge/releases/download/v0.6.0/CryptoDredge_0.6.0.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=4129696.0"
$Port = "313{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = ""} #Lyra2Re2
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = "--submit-stale"} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = ""} #Skunk
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

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-R 1 -N 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) --no-watchdog -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API = "CryptoDredge"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = $_.FaultTolerance
            ExtendInterval = $_.ExtendInterval
            DevFee = 1.0
        }
    }
}