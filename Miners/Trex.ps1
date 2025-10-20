using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://bitcointalk.org/index.php?topic=4432704.0"
$Port = "316{0:d2}"
$DevFee = 1.0
$Version = "0.26.8"
$DeviceCapability = "5.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Trex\t-rex"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.26.8-trex/t-rex-0.26.8-linux.tar.gz"
            Cuda   = "9.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Trex\t-rex.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri    = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.26.8-trex/t-rex-0.26.8-win.zip"
            Cuda   = "9.2"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3; DevFee = 2.0} #Autolykos2 (new with 0.21.0)
    [PSCustomObject]@{MainAlgorithm = "blake3"; Params = ""; MinMemGB = 2; ExtendInterval = 2} #Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "etchash"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3} #Etchash (new with 0.18.8)
    [PSCustomObject]@{MainAlgorithm = "etchash"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3; DualAll = $true} #Etchash+Blake3/ALPH (new with 0.26.6)
    [PSCustomObject]@{MainAlgorithm = "ethash"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; DAG = $true; Params = ""; MinMemGB = 1; ExtendInterval = 3; Algorithm = "ethash"} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; DAG = $true; Params = ""; MinMemGB = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; DAG = $true; Params = ""; MinMemGB = 3; ExtendInterval = 3; Algorithm = "ethash"} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; DAG = $true; Params = ""; MinMemGB = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash (new with v0.17.2, broken in v0.18.3, fixed with v0.18.5)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 2; ExtendInterval = 3} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 2; ExtendInterval = 3; DualAll = $true} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 1; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 1; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"; DualAll = $true} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 1; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 1; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash2g"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 1; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"; DualAll = $true} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash3g"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 3; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 3; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"; DualAll = $true} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 3; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 3; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash4g"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 3; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"; DualAll = $true} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethash5g"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 4; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; DAG = $true; Params = ""; MinMemGb = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash for low memory coins
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "autolykos2"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Autolycos2/ERG (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "blake3"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 2; ExtendInterval = 3; DualAll = $true; Algorithm = "ethash"} #Ethash+Blake3/ALPH (new with 0.25.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+FiroPow/RVN (new with 0.24.6)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "kawpow"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+KawPow/RVN (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "ethashlowmemory"; SecondAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 2; MinMemGB2nd = 4; ExtendInterval = 3; Algorithm = "ethash"} #Ethash+Octopus/CFX (new with 0.24.1)
    [PSCustomObject]@{MainAlgorithm = "firopow"; DAG = $true; Params = ""; MinMemGB = 4; ExtendInterval = 3} #FiroPoW (new with 0.22.0)
    [PSCustomObject]@{MainAlgorithm = "kawpow"; DAG = $true; Params = ""; ExtendInterval = 3} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "kawpow2g"; DAG = $true; Params = ""; ExtendInterval = 3; Algorithm = "kawpow"} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "kawpow3g"; DAG = $true; Params = ""; ExtendInterval = 3; Algorithm = "kawpow"} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "kawpow4g"; DAG = $true; Params = ""; ExtendInterval = 3; Algorithm = "kawpow"} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "kawpow5g"; DAG = $true; Params = ""; ExtendInterval = 3; Algorithm = "kawpow"} #KawPOW (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "mtp"; MinMemGB = 5; Params = ""; ExtendInterval = 2} #MTP
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; MinMemGB = 5; Params = ""; ExtendInterval = 2} #MTP-TCR (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "octopus"; DAG = $true; Params = ""; MinMemGB = 4; ExtendInterval = 2; DevFee = 2.0} #Octopus  (new with v0.19.0)
    [PSCustomObject]@{MainAlgorithm = "progpow-veil"; DAG = $true; Params = ""; ExtendInterval = 2} #ProgPowVeil (new with v0.18.1)
    [PSCustomObject]@{MainAlgorithm = "progpow-veriblock"; DAG = $true; Params = ""; ExtendInterval = 2} #vProgPow (new with v0.18.1)
    [PSCustomObject]@{MainAlgorithm = "progpowsero"; DAG = $true; Params = "--coin sero"; ExtendInterval = 2; Algorithm = "progpow"} #ProgPow  (new with v0.15.2)
    [PSCustomObject]@{MainAlgorithm = "progpowz"; DAG = $true; Params = ""; ExtendInterval = 2} #ProgpowZ (new with v0.17.2)
    [PSCustomObject]@{MainAlgorithm = "tensority"; Params = ""} #Tensority
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model -and (-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0)}

    if (-not $Device) {return}

    $Commands | ForEach-Object {
        $First = $True
        $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $SecondAlgorithm_Norm_0 = if ($_.SecondAlgorithm) {Get-Algorithm $_.SecondAlgorithm}
        
		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
            if (-not $Pools.$Algorithm_Norm.Host) {continue}

            $MinMemGB = if ($_.DAG) {if ($Pools.$Algorithm_Norm.DagSizeMax) {$Pools.$Algorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb}} else {$_.MinMemGb}
            if (-not $SecondAlgorithm_Norm_0 -and $_.DAG -and $Algorithm_Norm_0 -match $Global:RegexAlgoIsEthash -and $MinMemGB -gt $_.MinMemGB -and $Session.Config.EnableEthashZombieMode) {
                $MinMemGB = $_.MinMemGB
            }

            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

            $IsLHR = $true
            foreach($d in $Miner_Device) {
                $Model_Base = $d.Model_Base
                if ((-not $d.IsLHR -and -not $Session.Config.Devices.$Model_Base.EnableLHR) -or $Session.Config.Devices.$Model_Base.EnableLHR -eq $false) {
                    $IsLHR = $false
                    break
                }
            }

            if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {

                if ($First) {
                    $Miner_Port   = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name   = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($Algorithm_Norm_0)_$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $First = $False
                }

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                $Pool_Protocol = if ($Algorithm_Norm_0 -in @("Octopus")) {
                                    $Pools.$Algorithm_Norm.Protocol
                                    } else {
                                    Switch($Pools.$Algorithm_Norm.EthMode) {
                                        "qtminer"       {"stratum1+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratum2"   {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethstratumnh"  {"stratum2+$(if ($Pools.$Algorithm_Norm.SSL) {"ssl"} else {"tcp"})"}
                                        "ethlocalproxy" {"stratum+http"}
                                        default {$Pools.$Algorithm_Norm.Protocol}
                                    }
                                }

                if ($SecondAlgorithm_Norm_0) {

                    if ($_.DAG) {
                        $MinMemGB += if ($Pools.$SecondAlgorithm_Norm.DagSizeMax) {$Pools.$SecondAlgorithm_Norm.DagSizeMax} else {Get-EthDAGSize -CoinSymbol $Pools.$SecondAlgorithm_Norm.CoinSymbol -Algorithm $SecondAlgorithm_Norm_0 -Minimum $_.MinMemGB2nd}
                        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}
                    }

                    if ($Miner_Device -and $IsLHR -or $_.DualAll) {
        
        		        foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                            if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName)) {

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
					                Arguments      = "-N 10 -r 5 --api-bind-http 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) -o $($Pool_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Worker) {" -w $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"})$(if ($Pools.$Algorithm_Norm.SSL) {" --no-strict-ssl"}) --dual-algo $($_.SecondAlgorithm) --url2 $($Pool2_Protocol)://$($Pools.$SecondAlgorithm_Norm.Host):$($Pool2_Port) --user2 $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Wallet -and $Pools.$SecondAlgorithm_Norm.Worker) {" --worker2 $($Pools.$SecondAlgorithm_Norm.Worker)"})$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --pass2 $($Pools.$SecondAlgorithm_Norm.Pass)"})$(if (-not $Session.Config.ShowMinerWindow){" --no-color"}) --no-watchdog --no-new-block-info $($_.Params)"
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
                                    BaseAlgorithm  = "$($Algorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                                    ExcludePoolName = $_.ExcludePoolName
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
					    Arguments      = "-N 10 -r 5 --api-bind-http 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) -o $($Pool_Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Wallet -and $Pools.$Algorithm_Norm.Worker) {" -w $($Pools.$Algorithm_Norm.Worker)"})$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($Pools.$Algorithm_Norm.Failover | Select-Object | Foreach-Object {" -o $($_.Protocol)://$($_.Host):$($_.Port) -u $($_.User)$(if ($_.Pass) {" -p $($_.Pass)"})"})$(if ($Pools.$Algorithm_Norm.SSL) {" --no-strict-ssl"})$(if (-not $Session.Config.ShowMinerWindow){" --no-color"}) --no-watchdog --no-new-block-info $($_.Params)"
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
                        ExcludePoolName = $_.ExcludePoolName
				    }
                }
		    }
        }
    }
}
