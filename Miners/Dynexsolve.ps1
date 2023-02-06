using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

#if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $IsWindows) {return}

$ManualUri = "https://github.com/dynexcoin/Dynex/releases/tag/DynexSolve"
$Port = "352{0:d2}"
$DevFee = 0.0
$Version = "2.2.3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Dynexsolve\dynexsolve"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-ccminerradiator/ccminerradiator-1.0.0-cuda112-linux.7z"
            Cuda = "11.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Dynexsolve\DynexSolveVS.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2.3-dynexsolve/dynexsolve_windows2.2.3.7z"
            Cuda = "11.2"
        }
    )
}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "dynexsolve"; Params = ""; ExtendInterval = 2} #DynexSolve/DNX
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

$Device_Ids = @($Global:DeviceCache.AllDevices | Where-Object {$_.Type -eq "GPU" -and $_.Vendor -eq "NVIDIA"} | Select-Object -ExpandProperty Type_Vendor_Index -Unique)

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Model = $_.Model
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Device_Params = if (($Device_Ids | Measure-Object).Count -eq 1) {
        "-no-cpu"
    } else {
        $DisableDevices = @(Compare-Object $Device_Ids @($Miner_Device | Select-Object -ExpandProperty Type_Vendor_Index -Unique) | Where-Object {$_.SideIndicator -eq "<="} | Foreach-Object {$_.InputObject}) -join ','
        "-no-cpu -multi-gpu -disable-gpu $($DisableDevices)"
    }

    $Commands.ForEach({

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-mining-address $($Pools.$Algorithm_Norm.User) $($Device_Params) -stratum-url $($Pools.$Algorithm_Norm.Host) -stratum-port $($Pool_Port) -stratum-password $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "DynexsolveWrapper"
					Port           = $Miner_Port
					URI            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
                    DevFee         = 0.0
					ManualUri      = $ManualUri
					MiningPriority = 2
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                    ListDevices    = "-devices"
				}
			}
		}
    })
}