using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualURI = "https://github.com/NebuTech/NBMiner/releases"
$Port = "340{0:d2}"
$DevFee = 2.0
$Cuda = "9.1"
$Version = "39.3"

if ($IsLinux) {
    $Path = ".\Bin\GPU-NBMiner\nbminer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v39.3-nbminer/NBMiner_39.3_Linux.tgz"
} else {
    $Path = ".\Bin\GPU-NBMiner\nbminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v39.3-nbminer/NBMiner_39.3_Win.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$CuckooIntensity = if ($Global:GlobalCPUInfo.Cores -eq 1 -or $Global:GlobalCPUInfo.Threads -lt 4 -or $Global:GlobalCPUInfo.Name -match "Celeron") {4} else {2}

$Commands = [PSCustomObject[]]@(
    #Cuckoo
    [PSCustomObject]@{MainAlgorithm = "Aeternity";                 SecondaryAlgorithm = ""; Params = "-a cuckoo_ae --cuckoo-intensity $CuckooIntensity";     NH = $true;  MinMemGb = 5; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckoo29/Aeternity
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo31";                SecondaryAlgorithm = ""; Params = "-a cuckatoo --cuckoo-intensity $CuckooIntensity";      NH = $true;  MinMemGb = 8; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckatoo31
    [PSCustomObject]@{MainAlgorithm = "Cuckatoo32";                SecondaryAlgorithm = ""; Params = "-a cuckatoo32 --cuckoo-intensity $CuckooIntensity";    NH = $true;  MinMemGb = 6; DevFee = 2.0;  Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $true} #Cuckatoo31

    #Others
    [PSCustomObject]@{MainAlgorithm = "Autolykos2";                SecondaryAlgorithm = ""; Params = "-a ergo";          NH = $true; MinMemGb = 3;   DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Autolycos2/ERGO
    [PSCustomObject]@{MainAlgorithm = "BeamHash3";                 SecondaryAlgorithm = ""; Params = "-a beamv3";        NH = $true; MinMemGb = 3;   DevFee = 2.0; Vendor = @("NVIDIA");       ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #BEAM
    [PSCustomObject]@{MainAlgorithm = "Etchash";      DAG = $true; SecondaryAlgorithm = ""; Params = "-a etchash";       NH = $true; MinMemGb = 3;   DevFee = 1.0; Vendor = @("NVIDIA");       ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Etchash
    [PSCustomObject]@{MainAlgorithm = "Ethash";       DAG = $true; SecondaryAlgorithm = ""; Params = "-a ethash";        NH = $true; MinMemGb = 3;   DevFee = 1.0; Vendor = @("NVIDIA");       ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash
    [PSCustomObject]@{MainAlgorithm = "EthashLowMemory"; DAG = $true; SecondaryAlgorithm = ""; Params = "-a ethash";     NH = $true; MinMemGb = 2;   DevFee = 1.0; Vendor = @("NVIDIA");       ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "KawPOW";       DAG = $true; SecondaryAlgorithm = ""; Params = "-a kawpow";        NH = $true; MinMemGb = 2.4; DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #KAWPoW
    [PSCustomObject]@{MainAlgorithm = "Octopus";      DAG = $true; SecondaryAlgorithm = ""; Params = "-a octopus";       NH = $true; MinMemGb = 5;   DevFee = 3.0; Vendor = @("NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #Octopus/Conflux
    [PSCustomObject]@{MainAlgorithm = "ProgPowSero";  DAG = $true; SecondaryAlgorithm = ""; Params = "-a progpow_sero";  NH = $true; MinMemGb = 3;   DevFee = 2.0; Vendor = @("AMD","NVIDIA"); ExtendInterval = 2; Penalty = 0; NoCPUMining = $false} #ProgPowSero
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
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor}).ForEach({
            $First = $true

            $MainAlgorithm = $_.MainAlgorithm
            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm

			$SecondAlgorithm = $_.SecondaryAlgorithm
			$SecondAlgorithm_Norm = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

            $DualIntensity = $_.Intensity

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$MainAlgorithm_Norm_0.CoinSymbol -Algorithm $MainAlgorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

            if ($SecondAlgorithm_Norm) {
                $Miner_Config = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm)".Intensity
                if ($Miner_Config -and $Miner_Config -notcontains $DualIntensity) {$Miner_Device = $null}
            }

			foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
				if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and 
                        ($_.NH -or ($Pools.$MainAlgorithm_Norm.Host -notmatch "nicehash.com" -and ($SecondAlgorithm -eq '' -or $Pools.$SecondAlgorithm_Norm.Host -notmatch "nicehash.com"))) -and
                        ($SecondAlgorithm -eq '' -or $Pools.$MainAlgorithm_Norm.Host -notmatch "MiningPoolHub")
                    ) {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)$(if ($DualIntensity -ne $null) {"-$($DualIntensity)"})"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $offset = if ($Miner_Vendor -eq "AMD") {($Session.AllDevices | Where-Object Vendor -eq "NVIDIA" | Measure-Object).Count} else {0}
                        $DeviceIDsAll = ($Miner_Device | % {'{0:d}' -f ($_.Type_Vendor_Index + $offset)}) -join ','
                        if ($_.Intensity -ne $null) {
                            $DeviceIntensitiesAll = ",$($DualIntensity)"*($Miner_Device | Measure-Object).Count -replace '^,',' '
                        }
                        $First = $false
                    }
					$Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    $EthCoin = ""

                    $Pool_Protocol = Switch ($Pools.$MainAlgorithm_Norm.EthMode) {
                            "ethproxy" {$Pools.$MainAlgorithm_Norm.Protocol -replace "stratum","ethproxy"}
                            "ethstratumnh" {$Pools.$MainAlgorithm_Norm.Protocol -replace "stratum","nicehash"}
                            default {$Pools.$MainAlgorithm_Norm.Protocol}
                    }
                    if ($MainAlgorithm_Norm -eq "Etchash" -or $Pools.$MainAlgorithm_Norm.CoinSymbol -eq "ETC") {
                        $EthCoin = " --coin etc"
                    }

					if ($SecondAlgorithm -eq '') {
                        $FailoverMain = if ($Pools.$MainAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$MainAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$MainAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-o$i $($Pool_Protocol)://$($_.Host):$($_.Port) -u$i $($_.User)$(if ($_.Pass) {" -p$i $($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }

                        $Miner_EnvVars = if ($Miner_Vendor -eq "AMD") {"GPU_FORCE_64BIT_PTR=0"}
                        if ($IsLinux -and $MainAlgorithm_Norm_0 -match "^(KawPow|ProgPow|vProgPow)" -and @($env:LD_LIBRARY_PATH -split ':' | Select-Object) -inotcontains "/tmp") {
                            if ($Miner_EnvVars -eq $null) {$Miner_EnvVars = @()} else {$Miner_EnvVars = @($Miner_EnvVars)}
                            $Miner_EnvVars += "LD_LIBRARY_PATH=$(if ($env:LD_LIBRARY_PATH) {"$($env:LD_LIBRARY_PATH):"})/tmp"
                        }

						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -u $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"})$EthCoin$(if ($FailoverMain) {" $FailoverMain"}) --no-watchdog --share-check 0 $($_.Params)"
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
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            EnvVars        = $Miner_EnvVars
						}
					} else {
                        $Pool_Port2 = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                        $Pool_Protocol2 = Switch ($Pools.$SecondAlgorithm_Norm.EthMode) {
                                "ethproxy" {$Pools.$SecondAlgorithm_Norm.Protocol -replace "stratum","ethproxy"}
                                "ethstratumnh" {$Pools.$SecondAlgorithm_Norm.Protocol -replace "stratum","nicehash"}
                                default {$Pools.$SecondAlgorithm_Norm.Protocol}
                        }
                        $FailoverMain = if ($Pools.$MainAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$MainAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$MainAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-do$i $($Pool_Protocol)://$($_.Host):$($_.Port) -du$i $($_.User)$(if ($_.Pass) {" -dp$i $($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }
                        $FailoverSecondary = if ($Pools.$SecondAlgorithm_Norm.Failover) {
                            $i=1;
                            @($Pools.$SecondAlgorithm_Norm.Failover | Select-Object -First ([Math]::Min(2,$Pools.$SecondAlgorithm_Norm.Failover.Count)) | Foreach-Object {
                                "-o$i $($Pool_Protocol2)://$($_.Host):$($_.Port) -u$i $($_.User)$(if ($_.Pass) {" -p$i $($_.Pass)"})"
                                $i++
                            }) -join ' '
                        }

						[PSCustomObject]@{
							Name           = $Miner_Name
							DeviceName     = $Miner_Device.Name
							DeviceModel    = $Miner_Model
							Path           = $Path
							Arguments      = "--api 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Pool_Protocol2)://$($Pools.$SecondAlgorithm_Norm.Host):$($Pool_Port2) -u $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" -p $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if ($FailoverSecondary) {" $FailoverSecondary"}) -do $($Pool_Protocol)://$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port) -du $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -dp $($Pools.$MainAlgorithm_Norm.Pass)"})$EthCoin$(if ($FailoverMain) {" $FailoverMain"}) -di$($DeviceIntensitiesAll) --no-watchdog --no-health $($_.Params)"
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
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            EnvVars        = if ($Miner_Vendor -eq "AMD") {@("GPU_FORCE_64BIT_PTR=0")}
						}
					}
				}
			}
        })
    }
}