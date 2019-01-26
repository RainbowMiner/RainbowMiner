using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\CPU-Xmrig\xmrig.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.10.0-xmrig/xmrig-2.10.0-msvc-win64-rbm.7z"
$ManualUri = "https://github.com/xmrig/xmrig/releases"
$Port = "521{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2";          Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/half";       Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       Params = ""; Algorithm = "cryptonight/msr"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-turtle";     Params = ""}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $xmrig_algo = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path      = $Path
                Arguments = "-R 1 --api-port $($Miner_Port) -a $($xmrig_algo) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($DeviceParams) --keepalive$(if ($Pools.$Algorithm_Name.Name -eq "NiceHash") {" --nicehash"}) --donate-level=0 $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API       = "XMRig"
                Port      = $Miner_Port
                Uri       = $Uri
                DevFee    = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}