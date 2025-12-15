using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\GPU-OneZero\onezerominer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.7.3-onezerominer/onezerominer-linux-1.7.3.tar.gz"
} else {
    $Path = ".\Bin\GPU-OneZero\onezerominer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.7.3-onezerominer/onezerominer-win64-1.7.3.zip"
}

$ManualUri = "https://github.com/OneZeroMiner/onezerominer/releases"
$Port = "370{0:d2}"
$DevFee = 3.0
$Cuda = "11.8"
$Version = "1.7.3"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptix"; Params = ""; ExtendInterval = 3; Fee = @{NVIDIA=2.0}; Vendor = @("NVIDIA")} #CryptixOX8/CPAY
    [PSCustomObject]@{MainAlgorithm = "dynex"; Params = ""; ExtendInterval = 5; Fee = @{NVIDIA=2.0}; Vendor = @("NVIDIA")} #DynexSolve/DNX
    [PSCustomObject]@{MainAlgorithm = "qhash"; Params = ""; ExtendInterval = 2; Fee = @{NVIDIA=3.0}; Vendor = @("NVIDIA"); FaultTolerance = 0.4} #Qhash/QBC
    [PSCustomObject]@{MainAlgorithm = "xelis"; Params = ""; ExtendInterval = 3; Fee = @{NVIDIA=2.0;AMD=2.0}; Vendor = @("AMD","NVIDIA")} #XelisHashV3/XEL

    [PSCustomObject]@{MainAlgorithm = "xelis"; Params = ""; ExtendInterval = 3; Fee = @{NVIDIA=2.0;AMD=2.0}; Vendor = @("NVIDIA"); SecondaryAlgorithm = "qhash"; SecondaryFee = @{NVIDIA=3.0}} #XelisHashV3/XEL + Qhash/QBC
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

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
        $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object {$_.Model -eq $Miner_Model}

        $DisableCommand = if ($Miner_Vendor -eq "NVIDIA") {"--disable-amd"} else {"--disable-nvidia"}

        $Commands | Where-Object {$Miner_Vendor -in $_.Vendor} | ForEach-Object {
            $First = $true

            $MainAlgorithm_0 = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
            $MainAlgorithm_Norm_0 = Get-Algorithm $MainAlgorithm_0

            $SecondAlgorithm_Norm_0 = if ($_.SecondaryAlgorithm) {Get-Algorithm $_.SecondaryAlgorithm} else {$null}

		    foreach($MainAlgorithm_Norm in @($MainAlgorithm_Norm_0,"$($MainAlgorithm_Norm_0)-$($Miner_Model)","$($MainAlgorithm_Norm_0)-GPU")) {
			    if ($Pools.$MainAlgorithm_Norm.Host -and $Miner_Device -and (-not $_.IncludePoolName -or $Pools.$MainAlgorithm_Norm.Host -match $_.IncludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($SecondAlgorithm_Norm_0 | Select-Object | Foreach-Object {"$($MainAlgorithm_Norm_0)-$($_)"}) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                        $First = $false
                    }
				    $Pool_Port = if ($Pools.$MainAlgorithm_Norm.Ports -ne $null -and $Pools.$MainAlgorithm_Norm.Ports.GPU) {$Pools.$MainAlgorithm_Norm.Ports.GPU} else {$Pools.$MainAlgorithm_Norm.Port}

                    if ($SecondAlgorithm_Norm_0) {

                        $Miner_Intensity = $Session.Config.Miners."$($Name)-$($Miner_Model)-$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)".Intensity

                        if (-not $Miner_Intensity) {$Miner_Intensity = ""}

                        foreach($Intensity in @($Miner_Intensity)) {

                            if ($Intensity -ne "") {
                                $Miner_Name_Dual = (@($Name) + @("$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)-$($Intensity)") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                                $DeviceIntensitiesAll = (@($Intensity) * ($Miner_Device | Measure-Object).Count) -join ","
                            } else {
                                $Miner_Name_Dual = $Miner_Name
                                $DeviceIntensitiesAll = $null
                            }

                            foreach($SecondAlgorithm_Norm in @($SecondAlgorithm_Norm_0,"$($SecondAlgorithm_Norm_0)-$($Miner_Model)","$($SecondAlgorithm_Norm_0)-GPU")) {
                                if ($Pools.$SecondAlgorithm_Norm.Host -and $Pools.$SecondAlgorithm_Norm.User -and (-not $_.ExcludePoolName -or $Pools.$SecondAlgorithm_Norm.Host -notmatch $_.ExcludePoolName) -and (-not $_.CoinSymbol -or $_.CoinSymbol -icontains $Pools.$SecondAlgorithm_Norm.CoinSymbol) -and (-not $_.ExcludeCoinSymbol -or $_.ExcludeCoinSymbol -inotcontains $Pools.$SecondAlgorithm_Norm.CoinSymbol)) {

                                    $SecondPool_Port = if ($Pools.$SecondAlgorithm_Norm.Ports -ne $null -and $Pools.$SecondAlgorithm_Norm.Ports.GPU) {$Pools.$SecondAlgorithm_Norm.Ports.GPU} else {$Pools.$SecondAlgorithm_Norm.Port}

				                    [PSCustomObject]@{
					                    Name           = $Miner_Name_Dual
					                    DeviceName     = $Miner_Device.Name
					                    DeviceModel    = $Miner_Model
					                    Path           = $Path
					                    Arguments      = "$($DisableCommand) -d $($DeviceIDsAll) --d2 $($DeviceIDsAll)$(if ($DeviceIntensitiesAll) {" --dual-intensity $DeviceIntensitiesAll"}) -a $($_.MainAlgorithm) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"}) -o $(if ($Pools.$MainAlgorithm_Norm.SSL) {"$($Pools.$MainAlgorithm_Norm.Protocol)://"})$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) --a2 $($_.SecondaryAlgorithm) --w2 $($Pools.$SecondAlgorithm_Norm.User)$(if ($Pools.$SecondAlgorithm_Norm.Pass) {" --p2 $($Pools.$SecondAlgorithm_Norm.Pass)"}) --o2 $(if ($Pools.$SecondAlgorithm_Norm.SSL) {"$($Pools.$SecondAlgorithm_Norm.Protocol)://"})$($Pools.$SecondAlgorithm_Norm.Host):$($SecondPool_Port)$(if ($Pools.$SecondAlgorithm_Norm.Worker -and $Pools.$SecondAlgorithm_Norm.User -eq $Pools.$SecondAlgorithm_Norm.Wallet) {" --worker2 $($Pools.$SecondAlgorithm_Norm.Worker)"}) --api-port `$mport --disable-telemetry$($_.Params)"
					                    HashRates      = [PSCustomObject]@{
                                                            $MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Week
                                                            $SecondAlgorithm_Norm = $Global:StatsCache."$($Miner_Name_Dual)_$($SecondAlgorithm_Norm_0)_HashRate".Week
                                                        }
					                    API            = "OneZeroMiner"
					                    Port           = $Miner_Port
					                    Uri            = $Uri
                                        FaultTolerance = $_.FaultTolerance
					                    ExtendInterval = $_.ExtendInterval
                                        Penalty        = 0
					                    DevFee         = [PSCustomObject]@{
								                            ($MainAlgorithm_Norm) = if ($_.Fee -ne $null) {$_.Fee.$Miner_Vendor} else {$DevFee}
								                            ($SecondAlgorithm_Norm) = if ($_.SecondaryFee -ne $null) {$_.SecondaryFee.$Miner_Vendor} else {$DevFee}
                                                          }
					                    ManualUri      = $ManualUri
                                        Version        = $Version
                                        PowerDraw      = 0
                                        BaseName       = $Name
                                        BaseAlgorithm  = "$($MainAlgorithm_Norm_0)-$($SecondAlgorithm_Norm_0)"
                                        Benchmarked    = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                                        LogFile        = $Global:StatsCache."$($Miner_Name_Dual)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                                        EnvVars        = @()
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
					        Arguments      = "$($DisableCommand) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -w $($Pools.$MainAlgorithm_Norm.User)$(if ($Pools.$MainAlgorithm_Norm.Pass) {" -p $($Pools.$MainAlgorithm_Norm.Pass)"}) -o $(if ($Pools.$MainAlgorithm_Norm.SSL) {"$($Pools.$MainAlgorithm_Norm.Protocol)://"})$($Pools.$MainAlgorithm_Norm.Host):$($Pool_Port)$(if ($Pools.$MainAlgorithm_Norm.Worker -and $Pools.$MainAlgorithm_Norm.User -eq $Pools.$MainAlgorithm_Norm.Wallet) {" --worker $($Pools.$MainAlgorithm_Norm.Worker)"}) --api-port `$mport --disable-telemetry$($_.Params)"
					        HashRates      = [PSCustomObject]@{$MainAlgorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Week}
					        API            = "OneZeroMiner"
					        Port           = $Miner_Port
					        Uri            = $Uri
                            FaultTolerance = $_.FaultTolerance
					        ExtendInterval = $_.ExtendInterval
                            Penalty        = 0
					        DevFee         = if ($_.Fee -ne $null) {$_.Fee.$Miner_Vendor} else {$DevFee}
					        ManualUri      = $ManualUri
                            Version        = $Version
                            PowerDraw      = 0
                            BaseName       = $Name
                            BaseAlgorithm  = $MainAlgorithm_Norm_0
                            Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".Benchmarked
                            LogFile        = $Global:StatsCache."$($Miner_Name)_$($MainAlgorithm_Norm_0)_HashRate".LogFile
                            EnvVars        = @()
				        }
                    }
			    }
		    }
        }
    }
}
