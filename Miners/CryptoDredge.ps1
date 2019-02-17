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
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.17.0-cryptodredge/CryptoDredge_0.17.0_cuda_10.0_windows.zip"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.17.0-cryptodredge/CryptoDredge_0.17.0_cuda_9.2_windows.zip"
        Cuda = "9.2"
    }
)

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeon";      MinMemGb = 1; Params = ""} #Cryptolightv7 / Aeon
    [PSCustomObject]@{MainAlgorithm = "aeternity"; MinMemGb = 8; Params = ""} #Aeternity / Cuckoocycle
    [PSCustomObject]@{MainAlgorithm = "allium";    MinMemGb = 1; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "bcd";       MinMemGb = 1; Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";   MinMemGb = 1; Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11";       MinMemGb = 1; Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "cnfast";    MinMemGb = 2; Params = ""} #CryptonightFast
    [PSCustomObject]@{MainAlgorithm = "cnfast2";   MinMemGb = 2; Params = ""} #CryptonightFast2 / Masari
    [PSCustomObject]@{MainAlgorithm = "cngpu";     MinMemGb = 4; Params = ""} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cnhaven";   MinMemGb = 4; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy";   MinMemGb = 4; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnsaber";   MinMemGb = 4; Params = ""} #Cryptonightheavytube
    [PSCustomObject]@{MainAlgorithm = "cnsuperfast"; MinMemGb = 2; Params = ""} #CryptonightSuperFast / Swap
    [PSCustomObject]@{MainAlgorithm = "cnturtle";  MinMemGb = 4; Params = ""} #Cryptonightturtle
    [PSCustomObject]@{MainAlgorithm = "cnv7";      MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV7
    [PSCustomObject]@{MainAlgorithm = "cnv8";      MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV8 / Monero
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29"; MinMemGb = 8; Params = ""} #Cuckaroo29 / GRIN
    [PSCustomObject]@{MainAlgorithm = "dedal";     MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #Dedal
    [PSCustomObject]@{MainAlgorithm = "hmq1725";   MinMemGb = 1; Params = ""} #HMQ1725 (new in 0.10.0)
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";   MinMemGb = 1; Params = ""} #Lyra2Re3
    [PSCustomObject]@{MainAlgorithm = "Lyra2vc0banHash";   MinMemGb = 1; Params = ""} #Lyra2vc0banHash
    [PSCustomObject]@{MainAlgorithm = "lyra2z";    MinMemGb = 1; Params = ""} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "lyra2zz";   MinMemGb = 1; Params = ""} #Lyra2zz
    [PSCustomObject]@{MainAlgorithm = "mtp";       MinMemGb = 5; Params = ""; ExtendInterval = 2; DevFee = 2.0} #MTP
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; MinMemGb = 1; Params = ""} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "phi";       MinMemGb = 1; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2";      MinMemGb = 1; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "pipe";      MinMemGb = 1; Params = ""} #Pipe
    [PSCustomObject]@{MainAlgorithm = "skunk";     MinMemGb = 1; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "stellite";  MinMemGb = 1; Params = ""} #Stellite
    [PSCustomObject]@{MainAlgorithm = "tribus";    MinMemGb = 1; Params = ""; ExtendInterval = 2} #Tribus
    [PSCustomObject]@{MainAlgorithm = "x16r";      MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    #[PSCustomObject]@{MainAlgorithm = "x16rt";     MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16s";      MinMemGb = 1; Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";       MinMemGb = 1; Params = ""; ExtendInterval = 2} #X17
    [PSCustomObject]@{MainAlgorithm = "x21s";      MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";      MinMemGb = 1; Params = ""; ExtendInterval = 2} #X22i
)


$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $UriCuda.Uri
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
        
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)}

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        
        if ($Pools.$Algorithm_Norm.Host -and ($Algorithm_Norm -ne "Cuckaroo29" -or $Pools.$Algorithm_Norm.Name -ne "NiceHash") -and $Miner_Device) {
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
            $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-r 10 -R 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --log log_$($Miner_Port).txt $($_.Params) --no-nvml"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Ccminer"
                Port = $Miner_Port
                Uri = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee}
                ManualUri = $ManualUri
            }
        }
    }
}