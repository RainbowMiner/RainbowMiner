using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$Port = "316{0:d2}"
$DevFee = 1.0
$Version = "0.24.8"
$DeviceCapability = "5.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Trex\t-rex"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.24.8-trex/t-rex-0.24.8-linux.tar.gz"
            Cuda   = "9.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Trex\t-rex.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.24.8-trex/t-rex-0.24.8-win.zip"
            Cuda   = "9.2"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3; DevFee = 2.0} #Autolykos2 (new with 0.21.0)
    [PSCustomObject]@{MainAlgorithm = "etchash"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3} #Etchash (new with 0.18.8)
    [PSCustomObject]@{MainAlgorithm = "ethash"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3; DualZIL = $true} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 2; ExtendInterval = 3} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; Params = ""; MinMemGb = 2; ExtendInterval = 3; Algorithm = "ethash"; DualZIL = $true} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 4; ExtendInterval = 3} #FiroPoW (new with 0.22.0)
    [PSCustomObject]@{MainAlgorithm = "kawpow"; DAG = $true; Params = ""; ExtendInterval = 3} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "mtp"; MinMemGB = 5; Params = ""; ExtendInterval = 2} #MTP
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; MinMemGB = 5; Params = ""; ExtendInterval = 2} #MTP-TCR (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 4; ExtendInterval = 2; DevFee = 2.0} #Octopus  (new with v0.19.0)
    [PSCustomObject]@{MainAlgorithm = "progpow-veil"; DAG = $true; Params = ""; ExtendInterval = 2} #ProgPowVeil (new with v0.18.1)
    [PSCustomObject]@{MainAlgorithm = "progpow-veriblock"; DAG = $true; Params = ""; ExtendInterval = 2} #vProgPow (new with v0.18.1)
    [PSCustomObject]@{MainAlgorithm = "progpowsero"; DAG = $true; Params = "--coin sero"; ExtendInterval = 2; Algorithm = "progpow"} #ProgPow  (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "progpowz"; DAG = $true; Params = ""; ExtendInterval = 2} #ProgpowZ (new with v0.17.2)
    [PSCustomObject]@{MainAlgorithm = "tensority"; Params = ""} #Tensority
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

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model -and (-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)})

    if (-not $Device) {return}

    $Commands.ForEach({
        $First = $True
        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $SecondAlgorithm_Norm_0 = if ($_.SecondAlgorithm) {Get-Algorithm $_.SecondAlgorithm}
        
        $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
        if ($_.DAG) {
            if ($SecondAlgorithm_Norm_0) {
                $MinMemGB += Get-EthDAGSize -CoinSymbol $Pools.$SecondAlgorithm_Norm_0.CoinSymbol -Algorithm $SecondAlgorithm_Norm_0 -Minimum $_.MinMemGB2nd
            } elseif ($Algorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGB
            }
        }

        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

        $IsLHR = $true
        foreach($d in $Miner_Device) {if (-not $d.IsLHR) {$IsLHR = $false;break}}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
            if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {

                if ($First) {
                    $Miner_Port   = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name   = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($Algorithm_Norm_0)_$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    if ($Session.Config.Pools.Ezil.EnableTrexDual -and $_.DualZIL -and $Pools.ZilliqaETH -and $Pools.ZilliqaETH.Host -and $Pools.ZilliqaETH.Wallet -and $Pools.ZilliqaETH.EthMode -eq $Pools.$Algorithm_Norm.EthMode) {
                        $ZilPool = "$($Pools.ZilliqaETH.Protocol)://$($Pools.ZilliqaETH.Host):$($Pools.ZilliqaETH.Port)"
                        $ZilUser = $Pools.ZilliqaETH.User
                        $ZilPass = $Pools.ZilliqaETH.Pass
                    } else {
                        $ZilPool = ""
                        $ZilUser = ""
                        $ZilPass = ""
                    }
                    $First = $False
                }

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                $Pool_Protocol = if ($Algorithm_Norm_0 -in @("Octopus")) {
                                    $Pools.$Algorithm_Norm.Protocol
                                    } else {
                                    Switch($Pools.$Algorithm_Norm.EthMode) {
                                        "qtminer"       {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethlocalproxy" {"stratum+http"}
                                        default {$Pools.$Algorithm_Norm.Protocol}
                                    }
                                }

                if ($SecondAlgorithm_Norm_0) {

                    if ($IsLHR) {
        
        		        foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                            if ($Pools.$SecondAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Name -notmatch $_.ExcludePoolName)) {

				                $Pool2_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}
                                $Pool2_Protocol = if ($SecondAlgorithm_Norm -in @("Octopus")) {
                                                    $Pools.$SecondAlgorithm_Norm.Protocol
                                                 } else {
                                                    Switch($Pools.$SecondAlgorithm_Norm.EthMode) {
                                                        "qtminer"       {"stratum1+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                                        "ethstratumnh"  {"stratum2+$(if ($Pools.$SecondAlgorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                                        "ethlocalproxy" {"stratum+http"}
                                                        default {$Pools.$SecondAlgorithm_Norm.Protocol}
                                                    }
                                                }


				                [PSCustomObject]@{
					                Name           = $Miner_Name
					                DeviceName     = $Miner_Device.Name
					                DeviceModel    = $Miner_Model
					                Path           = $Path
					                Arguments      = "-N 10 -r 5 --api-bind-http 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) -o $($Pool_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Worker) {" -w $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"})$(if ($Pools.$Algorithm_Norm.SSL) {" --no-strict-ssl"}) --lhr-algo $($_.SecondAlgorithm) --url2 $($Pool2_Protocol)://$($Pools.$SecondAlgorithm_Norm.Host):$($Pool2_Port) --user2 $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Wallet -and $Pools.$SecondAlgorithm_Norm.Worker) {" --worker2 $($Pools.$SecondAlgorithm_Norm.Worker)"})$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --pass2 $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if (-not $Session.Config.ShowMinerWindow){" --no-color"}) --no-watchdog --no-new-block-info $($_.Params)"
							        HashRates      = [PSCustomObject]@{
                                                        $Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"
                                                        $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($SecondAlgorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"
                							        }
					                API            = "Trex"
					                Port           = $Miner_Port
					                Uri            = $Uri
                                    FaultTolerance = $_.FaultTolerance
					                ExtendInterval = $_.ExtendInterval
                                    Penalty        = 0
							        DevFee         = [PSCustomObject]@{
                                                        ($Algorithm_Norm) = if ($_.DevFee) {$_.DevFee} else {$DevFee}
                                                        ($SecondAlgorithm_Norm) = 0
							                        }
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
                    }

                } else {

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = "-N 10 -r 5 --api-bind-http 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) -o $($Pool_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Worker) {" -w $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"})$(if ($Pools.$Algorithm_Norm.SSL) {" --no-strict-ssl"})$(if ($ZilPool -and $ZilUser -and $ZilPass) {" --coin eth+zil --url2 $($ZilPool) --user2 $($ZilUser) --pass2 $($ZilPass) --extra-dag-epoch 0"})$(if (-not $Session.Config.ShowMinerWindow){" --no-color"}) --no-watchdog --no-new-block-info $($_.Params)"
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
					    API            = "Trex"
					    Port           = $Miner_Port
					    Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
					    DevFee         = if ($_.DevFee) {$_.DevFee} else {$DevFee}
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
        }
    })
}