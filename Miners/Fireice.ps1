using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.10.7-fireice/xmr-stak-win64-2.10.7-rbm-cuda10.1.7z"
        Cuda = "10.1"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.10.7-fireice/xmr-stak-win64-2.10.7-rbm-cuda10.0.7z"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.10.7-fireice/xmr-stak-win64-2.10.7-rbm-cuda9.0.7z"
        Cuda = "9.0"
    }
)
$Path = ".\Bin\CryptoNight-FireIce250\xmr-stak.exe"
$DevFee = 0.0
$Port = "309{0:d2}"
$ManualUri = "https://github.com/fireice-uk/xmr-stak/releases"
$Version = "2.10.7"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $Session.DevicesByTypes.AMD -and -not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/1";          Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v7"; Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/2";          Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v8"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/conceal";    Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_conceal"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/double";     Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v8_double"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_masari"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast2";      Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v8_half"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/r";          Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_r"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rwz";        Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v8_reversewaltz"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v7_stellite"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/zls";        Threads = 1; MinMemGb = 2; Algorithm = "cryptonight_v8_zelerius"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     Threads = 1; MinMemGb = 1; Algorithm = "cryptonight_lite"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     Threads = 1; MinMemGb = 1; Algorithm = "cryptonight_lite_v7"; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  Threads = 1; MinMemGb = 1; Algorithm = "cryptonight_lite_v7_xor"; Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/gpu";        Threads = 1; MinMemGb = 4; Algorithm = "cryptonight_gpu"; Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      Threads = 1; MinMemGb = 4; Algorithm = "cryptonight_heavy"; Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; Threads = 1; MinMemGb = 4; Algorithm = "cryptonight_bittube2"; Params = ""; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  Threads = 1; MinMemGb = 4; Algorithm = "cryptonight_haven"; Params = ""; ExtendInterval = 2}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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
if ($Session.DevicesByTypes.NVIDIA) {
    for($i=0;$i -le $UriCuda.Count -and -not $Uri;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri = $UriCuda[$i].Uri
            $Cuda= $UriCuda[$i].Cuda
        }
    }
}

if (-not $Uri) {$Uri  = $UriCuda[2].Uri}

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
	$Session.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model
            
        switch($Miner_Vendor) {
            "NVIDIA" {$Miner_Deviceparams = "--noUAC --noAMD --noCPU --openCLVendor NVIDIA"}
            "AMD" {$Miner_Deviceparams = "--noUAC --noCPU --noNVIDIA"}
            Default {$Miner_Deviceparams = "--noUAC --noAMD --noNVIDIA"}
        }

        $Commands | ForEach-Object {
            $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
            $MinMemGb = $_.MinMemGb
            $Params = $_.Params
        
            $Miner_Device = $Device | Where-Object {$_.Model -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

			foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
					$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
					$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
					$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

					$Pool_Port = if ($Miner_Model -ne "CPU" -and $Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
					$Arguments = [PSCustomObject]@{
						Params = "--httpd $($Miner_Port) $($Miner_Deviceparams) $($_.Params)".Trim()
						Config = [PSCustomObject]@{
							call_timeout    = 10
							retry_time      = 10
							giveup_limit    = 0
							verbose_level   = 3
							print_motd      = $true
							h_print_time    = 60
							aes_override    = $null
							use_slow_memory = "warn"
							tls_secure_algo = $true
							daemon_mode     = $false
							flush_stdout    = $false
							output_file     = ""
							httpd_port      = [Int]$Miner_Port
							http_login      = ""
							http_pass       = ""
							prefer_ipv4     = $true
						}
						Pools = [PSCustomObject]@{
                            pool_list = @([PSCustomObject]@{
								    pool_address    = "$($Pools.$Algorithm_Norm.Host):$($Pool_Port)"
								    wallet_address  = "$($Pools.$Algorithm_Norm.User)"
								    pool_password   = "$($Pools.$Algorithm_Norm.Pass)"
								    use_nicehash    = $($Pools.$Algorithm_Norm.Name -match "Nicehash")
								    use_tls         = $Pools.$Algorithm_Norm.SSL
								    tls_fingerprint = ""
								    pool_weight     = 1
								    rig_id = "$($Session.Config.Pools."$($Pools.$Algorithm_Norm.Name)".Worker)"
							    }
	    					)
                            currency        = $_.Algorithm
                        }

    					Devices = @($Miner_Device.Type_Vendor_Index)
						Vendor = $Miner_Vendor
                        Threads = 1
					}

					if ($Miner_Vendor -eq "CPU") {
                        #if ($Session.Config.CPUMiningThreads){$Arguments.Threads = $Session.Config.CPUMiningThreads}
                        #if ($Session.Config.CPUMiningAffinity -ne ''){$Arguments | Add-Member Affinity (ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity) -Force}
                    } else {
                        $Arguments.Config | Add-Member "platform_index" (($Miner_Device | Select-Object PlatformId -Unique).PlatformId)
                    }

					[PSCustomObject]@{
						Name           = $Miner_Name
						DeviceName     = $Miner_Device.Name
						DeviceModel    = $Miner_Model
						Path           = $Path
						Arguments      = $Arguments
						HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
						API            = "Fireice"
						Port           = $Miner_Port
						Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
						DevFee         = $DevFee
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
}