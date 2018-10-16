using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-Jceminer\jce_cn_gpu_miner64.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.33a-jceminer/jce_cn_gpu_miner.033a.zip"
$Port = "321{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=3281187.0"
$DevFee = 0.9

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Threads = 1; MinMemGb = 2; Params = "--variation 3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2";          Threads = 1; MinMemGb = 2; Params = "--variation 15"}
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
    $Device = $Session.Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $DevFee = 0.9

    $Commands | ForEach-Object {        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)})
        $DeviceIDsAll = $Device.Type_Vendor_Index -join ','

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path      = $Path
                Arguments = "-g $($DeviceIDsAll) --auto --no-cpu --doublecheck --mport $($Miner_Port) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash") {"--nicehash"}) $(if ($Pools.$Algorithm_Norm.SSL) {"--ssl"}) --stakjson --any $($_.Params)"
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