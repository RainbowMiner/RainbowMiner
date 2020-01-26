using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-XmrigUpx\xmrig-nvidia"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.14.4-xmrigupx/xmrig-nvidia-2.14.4_with_upx2-cuda10_1-linux-x64.7z"
            Cuda = "10.1"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-XmrigUpx\xmrig-nvidia.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.14.4-xmrigupx/xmrig-nvidia-2.14.4_with-upx2-cuda10_1-win64.7z"
            Cuda = "10.1"
        }
    )
}
$ManualUri = "https://github.com/Bendr0id/xmrig-nvidia/releases"
$Port = "303{0:d2}"
$DevFee = 0.0
$Version = "2.14.4"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cn-extremelite"; MinMemGb = 1; Params = ""}
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

$Global:DeviceCache.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $First = $true
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params

        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGb}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                $Arguments = [PSCustomObject]@{
                    PoolParams = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
                    DeviceParams = "--cuda-devices=$($Miner_Device.Type_Vendor_Index -join ',')"
                    Config = [PSCustomObject]@{
                        "algo"            = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                        "api" = [PSCustomObject]@{
                            "port"         = "`$mport"
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"       = $false
                        "colors"           = $true
                        "cuda-bfactor"     = 11
                        "cuda-max-threads" = 64
                        "donate-level"     = 0
                        "log-file"         = $null
                        "print-time"       = 5
                        "retries"          = 5
                        "retry-pause"      = 1
                    }
                    Devices = @($Miner_Device.Type_Vendor_Index)
                    HwSig   = "$($Miner_Model)-$(($Miner_Device.Type_Vendor_Index | Sort-Object | %{"{0:x}" -f $_}) -join '')"
                    Params  =  "--api-port=`$mport $Params".Trim()
                    Threads = 1
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "XMRig"
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
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    }
}