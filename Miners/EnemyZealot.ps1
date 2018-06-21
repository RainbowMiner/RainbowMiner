using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-enemyz\z-enemy.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.11-enemyzealot/z-enemy.1-11-public-final_v3.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=3378390.0"
$Port = "302{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeriumx"; Params = "-N 1"}, #AeriumX, new in 1.11
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = "-N 1"}, #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"}, # New in 1.11
    #[PSCustomObject]@{MainAlgorithm = "phi"; Params = "-N 1"}, #PHI
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = "-N 1"}, #Polytimos
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-N 1"}, #Skunk, new in 1.11
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "-N 1"}, #Timetravel8
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-N 1"}, #Tribus, new in 1.10
    #[PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 100"; ExtendInterval = 10; FaultTolerance = 0.5; HashrateDuration = "Day"}, #Raven, Ravencoin-Miner 3.0 is faster
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = ""}, #Pigeon
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "-N 1"}, #X17
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-N 1"}, #Xevan, new in 1.09a
    [PSCustomObject]@{MainAlgorithm = "vit"; Params = "-N 1"} #Vitality, new in 1.09a
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
            Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = $_.FaultTolerance
            ExtendInterval = $_.ExtendInterval
            DevFee = 1.0
        }
    }
}