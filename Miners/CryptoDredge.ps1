using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=4807821"
$Port = "313{0:d2}"
$DevFee = 1.0

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.5-cryptodredge/CryptoDredge_0.9.5_cuda_10.0_windows.zip"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.5-cryptodredge/CryptoDredge_0.9.5_cuda_9.2_windows.zip"
        Cuda = "9.2"
    }
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.5-cryptodredge/CryptoDredge_0.9.5_cuda_9.1_windows.zip"
        Cuda = "9.1"
    }
)

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeon";      MinMemGb = 1; Params = ""} #Cryptolightv7 / Aeon
    [PSCustomObject]@{MainAlgorithm = "allium";    MinMemGb = 1; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "bcd";       MinMemGb = 1; Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";       MinMemGb = 1; Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11";       MinMemGb = 1; Params = ""} #C11
    #[PSCustomObject]@{MainAlgorithm = "blake2s";   MinMemGb = 1; Params = ""} #Blake2s, ASIC domain. no longer profitable
    [PSCustomObject]@{MainAlgorithm = "cnfast";    MinMemGb = 2; Params = ""} #CryptonightFast / Masari
    [PSCustomObject]@{MainAlgorithm = "cnhaven";   MinMemGb = 4; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy";   MinMemGb = 4; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnsaber";   MinMemGb = 4; Params = ""} #Cryptonightheavytube
    [PSCustomObject]@{MainAlgorithm = "cnv7";      MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV7
    [PSCustomObject]@{MainAlgorithm = "cnv8";      MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV8 / Monero
    [PSCustomObject]@{MainAlgorithm = "exosis";    MinMemGb = 1; Params = ""} #Exosis
    [PSCustomObject]@{MainAlgorithm = "lbk3";      MinMemGb = 1; Params = ""} #LBK3
    [PSCustomObject]@{MainAlgorithm = "lyra2v2";   MinMemGb = 1; Params = ""} #Lyra2Re2
    [PSCustomObject]@{MainAlgorithm = "lyra2z";    MinMemGb = 1; Params = ""} #Lyra2z
    #[PSCustomObject]@{MainAlgorithm = "masari";    MinMemGb = 2; Params = ""} #Cryptonightfast / Masari
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; MinMemGb = 1; Params = ""} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "phi";       MinMemGb = 1; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2";      MinMemGb = 1; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "polytimos";      MinMemGb = 1; Params = ""} #Polytimos
    #[PSCustomObject]@{MainAlgorithm = "skein";     MinMemGb = 1; Params = ""} #Skein
    [PSCustomObject]@{MainAlgorithm = "skunk";     MinMemGb = 1; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "stellite";  MinMemGb = 1; Params = ""} #Stellite
    [PSCustomObject]@{MainAlgorithm = "tribus";    MinMemGb = 1; Params = ""; ExtendInterval = 2} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x17";       MinMemGb = 1; Params = ""} #X17
)


$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda[0].Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

$Uri = ""
for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri = $UriCuda[$i].Uri
        $Cuda= $UriCuda[$i].Cuda
    }
}
if (-not $Uri) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model    

    $Commands | ForEach-Object {
        $MinMemGb = $_.MinMemGb
        
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)})

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r 10 -R 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --log log_$($Miner_Port).txt $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "CryptoDredge"
                Port = $Miner_Port
                Uri = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = $DevFee
                ManualUri = $ManualUri
            }
        }
    }
}