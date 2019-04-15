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
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.18.0-cryptodredge/CryptoDredge_0.18.0_cuda_10.0_windows.zip"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.18.0-cryptodredge/CryptoDredge_0.18.0_cuda_9.2_windows.zip"
        Cuda = "9.2"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.18.0-cryptodredge/CryptoDredge_0.18.0_cuda_9.1_windows.zip"
        Cuda = "9.1"
    }
)

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeon";      MinMemGB = 1; Params = ""} #Cryptolightv7 / Aeon
    [PSCustomObject]@{MainAlgorithm = "aeternity"; MinMemGB = 6; MinMemGBW10 = 8; Params = ""} #Aeternity / Cuckoocycle
    [PSCustomObject]@{MainAlgorithm = "allium";    MinMemGB = 1; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "argon2d";   MinMemGB = 1; Params = ""} #Argon2d-Dyn
    [PSCustomObject]@{MainAlgorithm = "bcd";       MinMemGB = 1; Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";   MinMemGB = 1; Params = ""} #BitCore
    [PSCustomObject]@{MainAlgorithm = "c11";       MinMemGB = 1; Params = ""} #C11
    [PSCustomObject]@{MainAlgorithm = "cnfast";    MinMemGB = 2; Params = ""} #CryptonightFast
    [PSCustomObject]@{MainAlgorithm = "cnfast2";   MinMemGB = 2; Params = ""} #CryptonightFast2 / Masari
    [PSCustomObject]@{MainAlgorithm = "cngpu";     MinMemGB = 4; Params = ""} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cnhaven";   MinMemGB = 4; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy";   MinMemGB = 4; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnsaber";   MinMemGB = 4; Params = ""} #Cryptonightheavytube
    [PSCustomObject]@{MainAlgorithm = "cnsuperfast"; MinMemGB = 2; Params = ""} #CryptonightSuperFast / Swap
    [PSCustomObject]@{MainAlgorithm = "cnturtle";  MinMemGB = 4; Params = ""} #Cryptonightturtle
    [PSCustomObject]@{MainAlgorithm = "cnv7";      MinMemGB = 2; Params = ""; ExtendInterval = 2} #CryptonightV7
    [PSCustomObject]@{MainAlgorithm = "cnv8";      MinMemGB = 2; Params = ""; ExtendInterval = 2} #CryptonightV8 / Monero
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29"; MinMemGB = 4; MinMemGBW10 = 6; Params = ""; ExtendInterval = 2} #Cuckaroo29 / GRIN
    [PSCustomObject]@{MainAlgorithm = "dedal";     MinMemGB = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #Dedal
    [PSCustomObject]@{MainAlgorithm = "hmq1725";   MinMemGB = 1; Params = ""} #HMQ1725 (new in 0.10.0)
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";   MinMemGB = 1; Params = ""} #Lyra2Re3
    [PSCustomObject]@{MainAlgorithm = "Lyra2vc0banHash";   MinMemGB = 1; Params = ""} #Lyra2vc0banHash
    [PSCustomObject]@{MainAlgorithm = "lyra2z";    MinMemGB = 1; Params = ""} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "lyra2zz";   MinMemGB = 1; Params = ""} #Lyra2zz
    [PSCustomObject]@{MainAlgorithm = "mtp";       MinMemGB = 5; Params = ""; ExtendInterval = 2; DevFee = 2.0} #MTP
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; MinMemGB = 1; Params = ""} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "phi";       MinMemGB = 1; Params = ""} #PHI
    [PSCustomObject]@{MainAlgorithm = "phi2";      MinMemGB = 1; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "pipe";      MinMemGB = 1; Params = ""} #Pipe
    [PSCustomObject]@{MainAlgorithm = "skunk";     MinMemGB = 1; Params = ""} #Skunk
    [PSCustomObject]@{MainAlgorithm = "stellite";  MinMemGB = 1; Params = ""} #Stellite
    [PSCustomObject]@{MainAlgorithm = "tribus";    MinMemGB = 1; Params = ""; ExtendInterval = 2} #Tribus
    [PSCustomObject]@{MainAlgorithm = "veil";      MinMemGB = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; Algorithm = "x16rt"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "x16r";      MinMemGB = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";     MinMemGB = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16s";      MinMemGB = 1; Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";       MinMemGB = 1; Params = ""; ExtendInterval = 2} #X17
    [PSCustomObject]@{MainAlgorithm = "x21s";      MinMemGB = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X21s
    [PSCustomObject]@{MainAlgorithm = "x22i";      MinMemGB = 1; Params = ""; ExtendInterval = 2} #X22i
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
        $MinMemGb = if ($_.MinMemGBW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGBW10} else {$_.MinMemGB}
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        
		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
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
					Arguments = "-r 10 -R 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($Algorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --log log_$($Miner_Port).txt $($_.Params) --no-nvml"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
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
}