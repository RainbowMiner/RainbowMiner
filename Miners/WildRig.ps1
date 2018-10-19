using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-WildRig\wildrig.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.12.1.1b-wildrig/wildrig-multi-0.12.1.1-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 1.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "bcd"; Params = "--opencl-threads 3 --opencl-launch 19x128"} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore"; Params = "--opencl-threads 3 --opencl-launch 16x128"} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = "--opencl-threads 3 --opencl-launch 17x128"} #C11
    [PSCustomObject]@{MainAlgorithm = "geek"; Params = "--opencl-threads 2 --opencl-launch 18x128"} #Geek
    [PSCustomObject]@{MainAlgorithm = "hex"; Params = "--opencl-threads 3 --opencl-launch 20x128"} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725"; Params = "--opencl-threads 3 --opencl-launch 18x128"} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = "--opencl-threads 3 --opencl-launch 18x128"} #PHI
    [PSCustomObject]@{MainAlgorithm = "renesis"; Params = "--opencl-threads 3 --opencl-launch 21x128"} #Renesis
    [PSCustomObject]@{MainAlgorithm = "sonoa"; Params = "--opencl-threads 3 --opencl-launch 19x128"} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = "--opencl-threads 3 --opencl-launch 16x128"} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "--opencl-threads 3 --opencl-launch 20x0"} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = "--opencl-threads 3 --opencl-launch 18x128"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = "--opencl-threads 3 --opencl-launch 18x128"} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "--opencl-threads 3 --opencl-launch 20x0"} #X17
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
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
    $Miner_PlatformId = $Miner_Device | Select -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api-port $($Miner_Port) --algo $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -r 4 -R 10 --send-stale --donate-level 1 --opencl-devices $($DeviceIDsAll) --opencl-platform $($Miner_PlatformId) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "XMRig"
                Port = $Miner_Port
                Uri = $Uri
                DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}