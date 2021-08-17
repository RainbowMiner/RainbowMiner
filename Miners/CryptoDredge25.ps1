using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if ((-not $IsWindows -and -not $IsLinux) -or $Session.IsVM) {return}

$ManualUri = "https://github.com/technobyl/CryptoDredge/releases"
$Port = "363{0:d2}"
$DevFee = 1.0
$Version = "0.25.1"
$Enable_Logfile = $false
$DeviceCapability = "5.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CryptoDredge25\CryptoDredge"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.25.1-cryptodredge/CryptoDredge_0.25.1_cuda_10.2_linux.tar.gz"
            Cuda = "10.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.25.1-cryptodredge/CryptoDredge_0.25.1_cuda_9.2_linux.tar.gz"
            Cuda = "9.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-CryptoDredge25\CryptoDredge.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.25.1-cryptodredge/CryptoDredge_0.25.1_cuda_10.2_windows.zip"
            Cuda = "10.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.25.1-cryptodredge/CryptoDredge_0.25.1_cuda_9.2_windows.zip"
            Cuda = "9.2"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "aeternity";   MinMemGb = 5; Params = ""; ExcludePoolName = "^Nicehash"} #Aeternity / Cuckoocycle (bad rounding, see https://github.com/technobyl/CryptoDredge/issues/62)
    #[PSCustomObject]@{MainAlgorithm = "allium";      MinMemGb = 1; Params = ""} #Allium (CD 0.16.0 faster)
    [PSCustomObject]@{MainAlgorithm = "argon2d-dyn"; MinMemGb = 1; Params = ""} #Argon2d-Dyn
    [PSCustomObject]@{MainAlgorithm = "argon2d-nim"; MinMemGb = 1; Params = ""} #Argon2d-Nim
    [PSCustomObject]@{MainAlgorithm = "argon2d250";  MinMemGb = 1; Params = ""} #Argon2d250
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; MinMemGb = 3.3; Params = ""} #Argon2d4096
    #[PSCustomObject]@{MainAlgorithm = "bcd";         MinMemGb = 1; Params = ""} #BCD (trex faster)
    [PSCustomObject]@{MainAlgorithm = "chukwa";      MinMemGb = 1.5; Params = ""} #Chukwa, new with v0.21.0
    [PSCustomObject]@{MainAlgorithm = "chukwa-wrkz"; MinMemGb = 1.5; Params = ""; Legacy = $true} #Chukwa-Wrkz, new with v0.21.0
    [PSCustomObject]@{MainAlgorithm = "cnconceal";   MinMemGb = 1.5; Params = ""} #CryptonighConceal, new with v0.21.0
    [PSCustomObject]@{MainAlgorithm = "cnfast2";     MinMemGb = 1.5; Params = ""} #CryptonightFast2 / Masari
    [PSCustomObject]@{MainAlgorithm = "cngpu";       MinMemGb = 3.3; Params = ""} #CryptonightGPU
    [PSCustomObject]@{MainAlgorithm = "cnhaven";     MinMemGb = 3.3; Params = ""} #Cryptonighthaven
    [PSCustomObject]@{MainAlgorithm = "cnheavy";     MinMemGb = 3.3; Params = ""} #Cryptonightheavy
    [PSCustomObject]@{MainAlgorithm = "cnsaber";     MinMemGb = 3.3; Params = ""; Legacy = $true} #Cryptonightheavytube
    [PSCustomObject]@{MainAlgorithm = "cntlo";       MinMemGb = 3.3; Params = ""} #CryptonightTLO, new with v0.24.0
    [PSCustomObject]@{MainAlgorithm = "cnturtle";    MinMemGb = 3.3; Params = ""} #Cryptonightturtle
    [PSCustomObject]@{MainAlgorithm = "cnupx2";      MinMemGb = 1.5; Params = ""} #CryptoNightLiteUpx2, new with v0.23.0
    [PSCustomObject]@{MainAlgorithm = "cnzls";       MinMemGb = 3.3; Params = ""} #CryptonightZelerius, new with v0.23.0
    #[PSCustomObject]@{MainAlgorithm = "cuckaroo29";  MinMemGb = 3.3; Params = ""; ExtendInterval = 2} #Cuckaroo29
    [PSCustomObject]@{MainAlgorithm = "hmq1725";     MinMemGb = 1; Params = ""; Legacy = $true} #HMQ1725 (new in 0.10.0)
    #[PSCustomObject]@{MainAlgorithm = "lux";         MinMemGb = 1; Params = ""; Algorithm = "phi2"; Legacy = $true} #Lux/PHI2
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";     MinMemGb = 1; Params = ""; Legacy = $true} #Lyra2Re3
    [PSCustomObject]@{MainAlgorithm = "lyra2vc0ban"; MinMemGb = 1; Params = ""; Legacy = $true} #Lyra2vc0banHash
    [PSCustomObject]@{MainAlgorithm = "lyra2z";      MinMemGb = 1; Params = ""; Legacy = $true} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "lyra2zz";     MinMemGb = 1; Params = ""; Legacy = $true} #Lyra2zz
    [PSCustomObject]@{MainAlgorithm = "mtp";         MinMemGb = 5; Params = ""; ExtendInterval = 2; DevFee = 2.0} #MTP
    #[PSCustomObject]@{MainAlgorithm = "mtp-tcr";     MinMemGb = 5; Params = ""; ExtendInterval = 2} #MTP-TCR
    [PSCustomObject]@{MainAlgorithm = "neoscrypt";   MinMemGb = 1; Params = ""; Legacy = $true} #Neoscrypt
    #[PSCustomObject]@{MainAlgorithm = "phi2";        MinMemGb = 1; Params = ""; Legacy = $true} #PHI2 (CD 0.16.0 faster)
    [PSCustomObject]@{MainAlgorithm = "pipe";        MinMemGb = 1; Params = ""; Legacy = $true} #Pipe
    [PSCustomObject]@{MainAlgorithm = "sha256csm";   MinMemGb = 1; Params = ""; Legacy = $true} #Sha256csm, new with v0.24.0
    [PSCustomObject]@{MainAlgorithm = "skunk";       MinMemGb = 1; Params = ""; Legacy = $true} #Skunk
    [PSCustomObject]@{MainAlgorithm = "tribus";      MinMemGb = 1; Params = ""; Legacy = $true; ExtendInterval = 2} #Tribus
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

$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
    }
}

if (-not $Cuda) {return}

$Miners_IsMaxCUDAVersion = (Compare-Version "11.1" $Session.Config.CUDAVersion) -ge 1

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model -and (-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)})

    if (-not $Device) {return}

    $Commands.Where({$_.Legacy -or $Miners_IsMaxCUDAVersion}).ForEach({
        $First = $true
        $MinMemGb = $_.MinMemGb
        $Miner_Device = $Device | Where-Object {(Test-VRAM $_ $MinMemGb) -and ($_.OpenCL.Architecture -in @("Other","Pascal","Turing"))}

        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        
		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                if ($First) {
		            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
		            $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    #$Hashrate = if ($Algorithm -eq "argon2d-nim") {($Miner_Device | Foreach-Object {Get-NimqHashrate $_.Model} | Measure-Object -Sum).Sum}
                    $First = $false
                }
                if ($Algorithm -eq "argon2d-nim" -and $Pools.$Algorithm_Norm.Name -eq "Icemining") {
                    $Pool_Proto = "wss"
                    $Pool_User  = $Pools.$Algorithm_Norm.Wallet
                    if ($Pool_User -match "^([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})\s*([A-Z0-9]{4})$") {
                        $Pool_User = @(1..9 | Foreach-Object {$Matches[$_]}) -join " "
                    }
                    $Pool_UserAndPassword = "-u `"$Pool_User`" -p $($Pools.$Algorithm_Norm.Worker)"
                } else {
                    $Pool_Proto = $Pools.$Algorithm_Norm.Protocol
                    $Pool_UserAndPassword = "-u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})"
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-r 10 -R 1 -b 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) --no-watchdog -o $($Pool_Proto)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) $($Pool_UserAndPassword)$(if ($Hashrate) {" --hashrate $($hashrate)"})$(if ($Enable_Logfile) {" --log log_`$mport.txt"}) --no-nvml $($_.Params)" # --no-nvml"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
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
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				}
			}
		}
    })
}