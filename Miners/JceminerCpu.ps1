using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CPU-Jceminer\jce_cn_cpu_miner64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.32n-jceminer/jce_cn_cpu_miner.windows.032n.zip"
$Port = "320{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"
$DevFee = 1.5

$Devices = $Devices.CPU
if (-not $Devices -and -not $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Threads = 1; MinMemGb = 2; Params = "--variation 3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/mkt";        Threads = 1; MinMemGb = 2; Params = "--variation 9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/msr";        Threads = 1; MinMemGb = 2; Params = "--variation 11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        Threads = 1; MinMemGb = 2; Params = "--variation 10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        Threads = 1; MinMemGb = 2; Params = "--variation 8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        Threads = 1; MinMemGb = 2; Params = "--variation 7"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     Threads = 1; MinMemGb = 1; Params = "--variation 2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     Threads = 1; MinMemGb = 1; Params = "--variation 4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  Threads = 1; MinMemGb = 1; Params = "--variation 6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/red";   Threads = 1; MinMemGb = 1; Params = "--variation 14"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      Threads = 1; MinMemGb = 4; Params = "--variation 5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Threads = 1; MinMemGb = 4; Params = "--variation 13"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  Threads = 1; MinMemGb = 4; Params = "--variation 12"}
)

#N=1 Original Cryptonight
#N=2 Original Cryptolight
#N=3 Cryptonight V7 fork of April-2018
#N=4 Cryptolight V7 fork of April-2018
#N=5 Cryptonight-Heavy
#N=6 Cryptolight-IPBC
#N=7 Cryptonight-XTL
#N=8 Cryptonight-Alloy
#N=9 Cryptonight-MKT/B2N
#N=10 Cryptonight-ArtoCash
#N=11 Cryptonight-Fast (Masari)
#N=12 Cryptonight-Haven
#N=13 Cryptonight-Bittube v2
#N=14 Cryptolight-Red

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
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


$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Model = $_.Model
    $Miner_Threads = @(Get-CPUAffinity $Config.CPUMiningThreads | Select-Object)

    $DevFee = if($GLobal:GlobalCPUInfo.Features.aes -and $GLobal:GlobalCPUInfo.Features.'64bit'){1.5}else{3.0}

    $Commands | ForEach-Object {        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
       
        $Arguments = [PSCustomObject]@{Params = "--low --mport $($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {"--nicehash"}) $(if ($Pools.$Algorithm_Norm.SSL) {"--ssl"}) --stakjson --any $($_.Params)"}

        if ($Config.CPUMiningThreads) {
            $Arguments | Add-Member Config ([PSCustomObject]@{cpu_threads_conf = @($Miner_Threads | Foreach-Object {[PSCustomObject]@{cpu_architecture="auto";affine_to_cpu=$_;use_cache=$true;multi_hash=6}} | Select-Object)})
        } else {
            $Arguments.Params = "--auto $($Arguments.Params)"
        }

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path      = $Path
                Arguments = $Arguments
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API       = "Jceminer"
                Port      = $Miner_Port
                Uri       = $Uri
                DevFee    = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}