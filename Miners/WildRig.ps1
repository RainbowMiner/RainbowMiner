using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-WildRig\wildrig.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.14.0b-wildrig/wildrig-multi-0.14.0-beta.7z"
$ManualUri = "https://bitcointalk.org/index.php?topic=5023676.0"
$Port = "407{0:d2}"
$DevFee = 1.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo";      Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0")} #Aergo
    [PSCustomObject]@{MainAlgorithm = "bcd";        Params = @("--opencl-threads 2 --opencl-launch 19x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";    Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 19x0",   "--opencl-threads 2 --opencl-launch 19x0")} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11";        Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 19x0",   "--opencl-threads 2 --opencl-launch 19x0")} #C11
    [PSCustomObject]@{MainAlgorithm = "dedal";      Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #Dedal
    [PSCustomObject]@{MainAlgorithm = "geek";       Params = @("--opencl-threads 2 --opencl-launch 18x128", "--opencl-threads 2 --opencl-launch 20x128", "--opencl-threads 2 --opencl-launch 20x128")} #Geek
    [PSCustomObject]@{MainAlgorithm = "glt-astralhash"; Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0")} #GLT-AstralHash
    [PSCustomObject]@{MainAlgorithm = "glt-jeonghash";  Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0")} #GLT-JeongHash
    [PSCustomObject]@{MainAlgorithm = "glt-padihash";   Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0")} #GLT-PadiHash
    [PSCustomObject]@{MainAlgorithm = "glt-pawelhash";  Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 17x0")} #GLT-PawelHash
    [PSCustomObject]@{MainAlgorithm = "hex";        Params = @("--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 22x0",   "--opencl-threads 2 --opencl-launch 23x0")} #Hex
    [PSCustomObject]@{MainAlgorithm = "hmq1725";    Params = @("--opencl-threads 2 --opencl-launch 20x128", "--opencl-threads 2 --opencl-launch 20x128", "--opencl-threads 2 --opencl-launch 20x128")} #HMQ1725
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";    Params = @("--opencl-threads 1 --opencl-launch 21x0",   "--opencl-threads 1 --opencl-launch 23x0",   "--opencl-threads 1 --opencl-launch 23x0")} #Lyra2RE3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban";Params = @("--opencl-threads 1 --opencl-launch 21x0",   "--opencl-threads 1 --opencl-launch 23x0",   "--opencl-threads 1 --opencl-launch 23x0")} #Lyra2vc0ban
    [PSCustomObject]@{MainAlgorithm = "phi";        Params = @("--opencl-threads 3 --opencl-launch 19x0",   "--opencl-threads 3 --opencl-launch 19x0",   "--opencl-threads 3 --opencl-launch 19x0")} #PHI
    [PSCustomObject]@{MainAlgorithm = "renesis";    Params = @("--opencl-threads 3 --opencl-launch 17x0",   "--opencl-threads 3 --opencl-launch 17x128", "--opencl-threads 3 --opencl-launch 18x128")} #Renesis
    [PSCustomObject]@{MainAlgorithm = "skunkhash";  Params = @("--opencl-threads 3 --opencl-launch 17x0",   "--opencl-threads 3 --opencl-launch 18x0",   "--opencl-threads 3 --opencl-launch 18x0")} #Skunk
    [PSCustomObject]@{MainAlgorithm = "sonoa";      Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 18x0")} #Sonoa
    [PSCustomObject]@{MainAlgorithm = "timetravel"; Params = @("--opencl-threads 2 --opencl-launch 17x128", "--opencl-threads 2 --opencl-launch 17x128", "--opencl-threads 2 --opencl-launch 17x128")} #Timetravel
    [PSCustomObject]@{MainAlgorithm = "tribus";     Params = @("--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 21x0",   "--opencl-threads 2 --opencl-launch 21x0")} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x16r";       Params = @("--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16s";       Params = @("--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";        Params = @("--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #X17
    [PSCustomObject]@{MainAlgorithm = "x18";        Params = @("--opencl-threads 2 --opencl-launch 17x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #X18
    [PSCustomObject]@{MainAlgorithm = "x21s";       Params = @("--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 20x0",   "--opencl-threads 2 --opencl-launch 20x0")} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";       Params = @("--opencl-threads 2 --opencl-launch 19x0",   "--opencl-threads 2 --opencl-launch 18x0",   "--opencl-threads 2 --opencl-launch 18x0")} #X22i
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
    $Miner_Params = Switch ($Miner_Model) {
        "RX460" {0}
        "RX560" {0}
        "RX470" {1}
        "RX570" {1}
        "RX480" {2}
        "RX580" {2}
        default {0}
    }

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
    $Miner_PlatformId = $Miner_Device | Select -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api-port $($Miner_Port) --algo $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) -r 4 -R 10 --send-stale --donate-level 1 --multiple-instance --opencl-devices $($DeviceIDsAll) --opencl-platform $($Miner_PlatformId) $($_.Params[$Miner_Params])"
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