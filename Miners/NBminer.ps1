﻿using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-NBMiner\nbminer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v26.2-nbminer/NBMiner_26.2_Linux.tgz"
} else {
    $Path = ".\Bin\GPU-NBMiner\nbminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v26.2-nbminer/NBMiner_26.2_Win.zip"
}
$ManualURI = "https://github.com/NebuTech/NBMiner/releases"
$Port = "340{0:d2}"
$DevFee = 2.0
$Cuda = "9.1"
$Version = "26.2"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$CuckooIntensity = if ($Global:GlobalCPUInfo.Cores -eq 1 -or $Global:GlobalCPUInfo.Threads -lt 4 -or $Global:GlobalCPUInfo.Name -match "Celeron") {4} else {2}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Aeternity";    SecondaryAlgorithm = ""; Params = "-a cuckoo_ae --cuckoo-intensity $CuckooIntensity";     NH = $true;  MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckoo29/Aeternity
    [PSCustomObject]@{MainAlgorithm = "CuckooBFC";    SecondaryAlgorithm = ""; Params = "-a bfc --cuckoo-intensity $CuckooIntensity";           NH = $true;  MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckoo29/BFC
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29";   SecondaryAlgorithm = ""; Params = "-a cuckaroo --cuckoo-intensity $CuckooIntensity";      NH = $true;  MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29/BitGRIN
    [PSCustomObject]@{MainAlgorithm = "Cuckarood29";  SecondaryAlgorithm = ""; Params = "-a cuckarood --cuckoo-intensity $CuckooIntensity";     NH = $true;  MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckarood29/GRIN
    [PSCustomObject]@{MainAlgorithm = "Cuckaroo29s";  SecondaryAlgorithm = ""; Params = "-a cuckaroo_swap --cuckoo-intensity $CuckooIntensity"; NH = $true;  MinMemGb = 5;  MinMemGbW10 = 6;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckaroo29s/SWAP
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";   SecondaryAlgorithm = ""; Params = "-a cuckatoo --cuckoo-intensity $CuckooIntensity";      NH = $true;  MinMemGb = 8;  MinMemGbW10 = 10; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Eaglesong";    SecondaryAlgorithm = ""; Params = "-a eaglesong";     NH = $true; MinMemGb = 4; DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Eaglesong"; Params = "-a eaglesong_ethash"; NH = $true; MinMemGb = 4; DevFee = 3.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + CKB
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = ""; Params = "-a ethash";        NH = $true; MinMemGb = 4;  DevFee = 0.65; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    [PSCustomObject]@{MainAlgorithm = "ProgPow";      SecondaryAlgorithm = ""; Params = "-a progpow_sero";  NH = $true; MinMemGb = 4;  DevFee = 0.65; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #ProgPowSero
    [PSCustomObject]@{MainAlgorithm = "ScryptSIPC";   SecondaryAlgorithm = ""; Params = "-a sipc";          NH = $true; MinMemGb = 1;  DevFee = 2.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    [PSCustomObject]@{MainAlgorithm = "Ethash";       SecondaryAlgorithm = "Tensority"; Params = "-a tensority_ethash"; NH = $true; MinMemGb = 4; DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash + BTM
    [PSCustomObject]@{MainAlgorithm = "Tensority";    SecondaryAlgorithm = ""; Params = "-a tensority";     NH = $true; MinMemGb = 1;  DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #BTM
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","NVIDIA")
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

if ($Global:DeviceCache.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","NVIDIA")) {
	$Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object Type -eq "GPU" | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $true
            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm
			$SecondAlgorithm = $_.SecondaryAlgorithm
			if ($SecondAlgorithm -ne '') {
				$SecondAlgorithm_Norm = Get-Algorithm $SecondAlgorithm
			}

            $MinMemGB = if ($_.MainAlgorithm -eq "Ethash") {Get-EthDAGSize $Pools.$MainAlgorithm_Norm_0.CoinSymbol} elseif ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and 
                        ($MainAlgorithm -ne "Ethash" -or $Pools.$MainAlgorithm_Norm.Name -ne "MiningRigRentals") -and 
                        ($MainAlgorithm -ne "ProgPow" -or $Pools.$MainAlgorithm_Norm.CoinSymbol -eq "SERO") -and
                        ($_.NH -or ($Pools.$MainAlgorithm_Norm.Name -notmatch "Nicehash" -and ($SecondAlgorithm -eq '' -or $Pools.$SecondAlgorithm_Norm.Name -notmatch "Nicehash")))
                    ) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = if ($SecondAlgorithm -eq '') {
			                (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        } else {
                            (@($Name) + @($MainAlgorithm_Norm_0) + @($SecondAlgorithm_Norm) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        }
                        $offset = if ($Miner_Vendor -eq "AMD") {($Session.AllDevices | Where-Object Vendor -eq "NVIDIA" | Measure-Object).Count} else {0}
                        $DeviceIDsAll = ($Miner_Device | % {'{0:d}' -f ($_.Type_Vendor_Index + $offset)}) -join ','
                        $First = $false
                    }
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    $Stratum = $Pools.$MainAlgorithm_Norm.Protocol
                    if ($MainAlgorithm_Norm -match "^(Ethash|ProgPow)") {
                        Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                            "ethproxy" {$Stratum = $Stratum -replace "stratum","ethproxy"}
                            "ethstratumnh" {$Stratum = $Stratum -replace "stratum","nicehash"}
                        }
                    }

					if ($SecondAlgorithm -eq '') {
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.User -match '^solo:') {"."})$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"}) --no-watchdog --no-nvml $($_.Params)"
							HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
							API            = "NBminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = $_.DevFee
					        FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            EnvVars        = if ($IsLinux -and $MainAlgorithm_Norm_0 -eq "ProgPow" -and @($env:LD_LIBRARY_PATH -split ':' | Select-Object) -inotcontains "/tmp") {@("LD_LIBRARY_PATH=$(if ($env:LD_LIBRARY_PATH) {"$($env:LD_LIBRARY_PATH):"})/tmp")}
						}
					} else {
                        $Pool_Port2 = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                        $Stratum2 = $Pools.$SecondAlgorithm_Norm.Protocol
                        if ($SecondAlgorithm_Norm -match "^(Ethash|ProgPow)") {
                            Switch ($Pools.$SecondAlgorithm_Norm.EthMode) {
                                "ethproxy" {$Stratum2 = $Stratum2 -replace "stratum","ethproxy"}
                                "ethstratumnh" {$Stratum2 = $Stratum2 -replace "stratum","nicehash"}
                            }
                        }
						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Stratum2)://$($Pools.$SecondAlgorithm_Norm.Host):$($Pool_Port2) -u $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {":$($Pools.$SecondAlgorithm_Norm.Pass)"}) -do $($Stratum)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -du $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.User -match '^solo:') {"."})$(if ($Pools.$MainAlgorithm_Norm.Pass) {":$($Pools.$MainAlgorithm_Norm.Pass)"}) --no-watchdog --no-nvml $($_.Params)"
							HashRates      = [PSCustomObject]@{
                                                $MainAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                                                $SecondAlgorithm_Norm = $($Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1}))
                							}
							API            = "NBminer"
							Port           = $Miner_Port
							Uri            = $Uri
							DevFee         = [PSCustomObject]@{
                                                ($MainAlgorithm_Norm) = $_.DevFee
                                                ($SecondAlgorithm_Norm) = 0
							                }
					        FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
							ManualUri      = $ManualUri
							NoCPUMining    = $_.NoCPUMining
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)"
                            EnvVars        = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")}
						}
					}
				}
			}
        }
    }
}