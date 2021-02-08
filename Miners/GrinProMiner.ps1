﻿using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\GPU-GrinPro\bin\GrinProMiner"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2-grinpro/GrinPro_2_2_Linux64.tar.gz"
    $Vendors = @("AMD")
} else {
    $Path = ".\Bin\GPU-GrinPro\GrinProMiner.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2-grinpro/GrinPro_2_XWP_Win64.zip"
    $Vendors = @("AMD")
}
$ManualURI = "https://grinpro.io"
$Port = "335{0:d2}"
$DevFee = 2.0
$Cuda = "10.0"
$Version = "2.2"

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cuckaroo29s"; MinMemGb = 6; Params = ""; DevFee = 2.0; ExtendInterval = 3; FaultTolerance = 0.3; Penalty = 0; Vendor = @("AMD"); NoCPUMining = $true} #XWP/Cuckaroo29s
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
            $MinMemGb = $_.MinMemGb
            $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

            $Algorithm = $_.MainAlgorithm
            $Algorithm_Norm_0 = Get-Algorithm $Algorithm

			foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
				if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and $Pools.$Algorithm_Norm.Name -notmatch "nicehash") {
                    if ($First) {
			            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
			            $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                    }
					$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
                
					$Arguments = [PSCustomObject]@{
						Params = "api-port=`$mport $($_.Params)".Trim()
						Config = [PSCustomObject]@{
							Host = $Pools.$Algorithm_Norm.Host
							Port = $Pool_Port
							SSL  = $Pools.$Algorithm_Norm.SSL
							User = $Pools.$Algorithm_Norm.User
							Pass = $Pools.$Algorithm_Norm.Pass
						}
						Device = @($Miner_Device | Foreach-Object {[PSCustomObject]@{Name=$_.Model_Name;Vendor=$_.Vendor;Index=$_.Type_Vendor_Index;PlatformId=$_.PlatformId}})
					}

					[PSCustomObject]@{
						Name           = $Miner_Name
						DeviceName     = $Miner_Device.Name
						DeviceModel    = $Miner_Model
						Path           = $Path
						#Arguments      = "ignore-config=true $($DeviceIDsAll) api-port=`$mport stratum-address=$($Pools.$Algorithm_Norm.Host) stratum-port=$($Pools.$Algorithm_Norm.Port) stratum-login=$($Pools.$Algorithm_Norm.User) $(if ($Pools.$Algorithm_Norm.Pass) {"stratum-password=$($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)"
						Arguments      = $Arguments
						HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week * $(if ($_.Penalty) {1-$_.Penalty/100} else {1})}
						API            = "GrinPro"
						Port           = $Miner_Port
						Uri            = $Uri
                        FaultTolerance = $_.FaultTolerance
					    ExtendInterval = $_.ExtendInterval
                        Penalty        = 0
						DevFee         = $_.DevFee
						ManualUri      = $ManualUri
						StopCommand    = if ($IsWindows) {"Sleep 15; Get-CIMInstance CIM_Process | Where-Object ExecutablePath | Where-Object {`$_.ExecutablePath -like `"$([IO.Path]::GetFullPath($Path) | Split-Path)\*`"} | Select-Object ProcessId,ProcessName | Foreach-Object {Stop-Process -Id `$_.ProcessId -Force -ErrorAction Ignore}"} else {$null}
						NoCPUMining    = $_.NoCPUMining
						DotNetRuntime  = if ($IsWindows) {"2.0"} else {$null}
                        Version        = $Version
                        PowerDraw      = 0
                        BaseName       = $Name
                        BaseAlgorithm  = $Algorithm_Norm_0
					}
				}
			}
        })
    }
}