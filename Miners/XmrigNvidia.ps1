using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$Path = ".\Bin\NVIDIA-Xmrig\xmrig-nvidia.exe"
$ManualUri = "https://github.com/xmrig/xmrig-nvidia/releases"
$Port = "303{0:d2}"
$DevFee = 0.0
$Version = "2.14.5"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.14.5-xmrig/xmrig-nvidia-2.14.5-msvc-win64-rbm.7z"
        Cuda = "10.1"
    }
)

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cryptonight/1";          MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/2";          MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/double";     MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/gpu";        MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/half";       MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/fast";       MinMemGb = 2; Params = ""; Algorithm = "cryptonight/msr"}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/r";          MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rto";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/rwz";        MinMemGb = 2; Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight/wow";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xao";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/xtl";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight/zls";        MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/0";     MinMemGb = 1; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-lite/1";     MinMemGb = 1; Params = ""}
    #[PSCustomObject]@{MainAlgorithm = "cryptonight-lite/ipbc";  MinMemGb = 2; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy";      MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/tube"; MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-heavy/xhv";  MinMemGb = 4; Params = ""}
    [PSCustomObject]@{MainAlgorithm = "cryptonight-turtle";     MinMemGb = 4; Params = ""}
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

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params

        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

                $Arguments = [PSCustomObject]@{
                    PoolParams = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
                    DeviceParams = "--cuda-devices=$($Miner_Device.Type_Vendor_Index -join ',')"
                    Config = [PSCustomObject]@{
                        "algo"            = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                        "api" = [PSCustomObject]@{
                            "port"         = $Miner_Port
                            "access-token" = $null
                            "worker-id"    = $null
                        }
                        "background"       = $false
                        "colors"           = $true
                        "cuda-bfactor"     = 11
                        "cuda-max-threads" = 64
                        "donate-level"     = if ($IsLinux) {1} else {0}
                        "log-file"         = $null
                        "print-time"       = 5
                        "retries"          = 5
                        "retry-pause"      = 1
                    }
                    Devices = @($Miner_Device.Type_Vendor_Index)
                    HwSig   = "$($Miner_Model)-$(($Miner_Device.Type_Vendor_Index | Sort-Object | %{"{0:x}" -f $_}) -join '')"
                    Params  =  $Params
                    Threads = 1
                }

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
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
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}