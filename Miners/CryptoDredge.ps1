using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=4807821"
$Port = "313{0:d2}"
$DevFee = 1.0
$Version = "0.22.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_linux_x64_cuda_10.1.tar.gz"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_linux_x64_cuda_10.0.tar.gz"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_linux_x64_cuda_9.2.tar.gz"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_linux_x64_cuda_9.1.tar.gz"
            Cuda = "9.1"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-CryptoDredge\CryptoDredge.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_win_x64_cuda_10.1.zip"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_win_x64_cuda_10.0.zip"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_win_x64_cuda_9.2.zip"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.22.0-cryptodredge/CryptoDredge_0.22.0_win_x64_cuda_9.1.zip"
            Cuda = "9.1"
        }
    )
}

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aeon";        NH = $true;  MinMemGb = 1; Params = ""} #Cryptolightv7 / Aeon
    #[PSCustomObject]@{MainAlgorithm = "aeternity";   NH = $false; MinMemGb = 6; MinMemGbW10 = 8; Params = ""} #Aeternity / Cuckoocycle
    #[PSCustomObject]@{MainAlgorithm = "allium";      NH = $true;  MinMemGb = 1; Params = ""} #Allium (CD 0.16.0 faster)
    [PSCustomObject]@{MainAlgorithm = "argon2d-dyn"; NH = $true;  MinMemGb = 1; Params = ""} #Argon2d-Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2d-nim"; NH = $true;  MinMemGb = 1; Params = ""} #Argon2d-Nim
    [PSCustomObject]@{MainAlgorithm = "argon2d250";  NH = $true;  MinMemGb = 1; Params = ""} #Argon2d250
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; NH = $true;  MinMemGb = 4; Params = ""} #Argon2d4096
    [PSCustomObject]@{MainAlgorithm = "bcd";         NH = $true;  MinMemGb = 1; Params = ""} #BCD
    [PSCustomObject]@{MainAlgorithm = "bitcore";     NH = $true;  MinMemGb = 1; Params = ""} #BitCore
    #[PSCustomObject]@{MainAlgorithm = "c11";         NH = $true;  MinMemGb = 1; Params = ""} #C11, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "chukwa";      NH = $true;  MinMemGb = 2; Params = ""} #Chukwa, new with v0.21.0
    [PSCustomObject]@{MainAlgorithm = "chukwa-wrkz"; NH = $true;  MinMemGb = 2; Params = ""} #Chukwa-Wrkz, new with v0.21.0
    [PSCustomObject]@{MainAlgorithm = "cnconceal";    NH = $true;  MinMemGb = 2; Params = ""} #CryptonighConceal, new with v0.21.0
    #[PSCustomObject]@{MainAlgorithm = "cnfast";      NH = $true;  MinMemGb = 2; Params = ""} #CryptonightFast, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "cnfast2";     NH = $true;  MinMemGb = 2; Params = ""} #CryptonightFast2 / Masari
    [PSCustomObject]@{MainAlgorithm = "cngpu";       NH = $true;  MinMemGb = 4; Params = ""} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cnhaven";     NH = $true;  MinMemGb = 4; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy";     NH = $true;  MinMemGb = 4; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnsaber";     NH = $true;  MinMemGb = 4; Params = ""} #Cryptonightheavytube
    #[PSCustomObject]@{MainAlgorithm = "cnsuperfast";   NH = $true;  MinMemGb = 2; Params = ""} #CryptonightSuperFast, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "cnturtle";    NH = $true;  MinMemGb = 4; Params = ""} #Cryptonightturtle
    #[PSCustomObject]@{MainAlgorithm = "cnv7";        NH = $true;  MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV7, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "cnv8";        NH = $true;  MinMemGb = 2; Params = ""; ExtendInterval = 2} #CryptonightV8 / Monero
    #[PSCustomObject]@{MainAlgorithm = "cuckaroo29";  NH = $true;  MinMemGb = 4; MinMemGbW10 = 6; Params = ""; ExtendInterval = 2} #Cuckaroo29 / GRIN
    #[PSCustomObject]@{MainAlgorithm = "dedal";       NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #Dedal, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "hmq1725";     NH = $true;  MinMemGb = 1; Params = ""} #HMQ1725 (new in 0.10.0)
    [PSCustomObject]@{MainAlgorithm = "lux";         NH = $true;  MinMemGb = 1; Params = ""; Algorithm = "phi2"} #Lux/PHI2
    #[PSCustomObject]@{MainAlgorithm = "lyra2v3";     NH = $true;  MinMemGb = 1; Params = ""} #Lyra2Re3 (CD 0.16.0 faster)
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban"; NH = $true;  MinMemGb = 1; Params = ""} #Lyra2vc0banHash
    [PSCustomObject]@{MainAlgorithm = "lyra2z";      NH = $true;  MinMemGb = 1; Params = ""} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "lyra2zz";     NH = $true;  MinMemGb = 1; Params = ""} #Lyra2zz
    [PSCustomObject]@{MainAlgorithm = "mtp";         NH = $true;  MinMemGb = 5; Params = ""; ExtendInterval = 2; DevFee = 2.0} #MTP
    #[PSCustomObject]@{MainAlgorithm = "neoscrypt";   NH = $true;  MinMemGb = 1; Params = ""} #Neoscrypt (CD 0.16.0 faster)
    #[PSCustomObject]@{MainAlgorithm = "phi";         NH = $true;  MinMemGb = 1; Params = ""} #PHI, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "phi2";        NH = $true;  MinMemGb = 1; Params = ""} #PHI2
    [PSCustomObject]@{MainAlgorithm = "pipe";        NH = $true;  MinMemGb = 1; Params = ""} #Pipe
    [PSCustomObject]@{MainAlgorithm = "skunk";       NH = $true;  MinMemGb = 1; Params = ""} #Skunk
    #[PSCustomObject]@{MainAlgorithm = "stellite";    NH = $true;  MinMemGb = 1; Params = ""} #Stellite, disabled v0.19.0
    [PSCustomObject]@{MainAlgorithm = "tribus";      NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 2} #Tribus
    [PSCustomObject]@{MainAlgorithm = "veil";        NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"; Algorithm = "x16rt"} #X16rt-VEIL
    [PSCustomObject]@{MainAlgorithm = "x16r";        NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16r
    [PSCustomObject]@{MainAlgorithm = "x16rt";       NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rt
    [PSCustomObject]@{MainAlgorithm = "x16rv2";      NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16rv2
    [PSCustomObject]@{MainAlgorithm = "x16s";        NH = $true;  MinMemGb = 1; Params = ""} #X16s
    [PSCustomObject]@{MainAlgorithm = "x17";         NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 2} #X17
    [PSCustomObject]@{MainAlgorithm = "x21s";        NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 3; FaultTolerance = 0.7; HashrateDuration = "Day"} #X21s
    #[PSCustomObject]@{MainAlgorithm = "x22i";        NH = $true;  MinMemGb = 1; Params = ""; ExtendInterval = 2} #X22i
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
        $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $Hashrate = if ($Algorithm -eq "argon2d-nim") {($Miner_Device | Foreach-Object {Get-NimqHashrate $_.Model} | Measure-Object -Sum).Sum}
        
		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash")) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

				$DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-r 10 -R 1 -b 127.0.0.1:$($Miner_Port) -d $($DeviceIDsAll) -a $($Algorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Hashrate) {"  --hashrate $($hashrate)"}) --log log_$($Miner_Port).txt --no-nvml $($_.Params)" # --no-nvml"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = if ($_.DevFee -ne $null) {$_.DevFee} else {$DevFee}
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}