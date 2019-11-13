using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\ANY-Xmrig\xmrig"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.0-xmrig/xmrig-5.0.0-xenial-cuda10_1-x64.7z"
    $CudaLib = "libxmrig-cuda.so"
    $DevFee = 1.0
} else {
    $Path = ".\Bin\ANY-Xmrig\xmrig.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.0.0-xmrig/xmrig-5.0.0-msvc-cuda10_1-win64.7z"
    $CudaLib = "xmrig-cuda.dll"
    $DevFee = 0.0
}
$ManualUri = "https://github.com/xmrig/xmrig/releases"
$Port = "350{0:d2}"
$Cuda = "10.1"
$Version = "5.0.0"

if (-not $Session.DevicesByTypes.AMD -and -not $Session.DevicesByTypes.CPU -and -not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

if ($Session.DevicesByTypes.NVIDIA -and -not $CudaLib) {return}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwa"; MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/wrkz";   MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    #[PSCustomObject]@{MainAlgorithm = "cn/1";          MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    #[PSCustomObject]@{MainAlgorithm = "cn/2";          MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/double";     MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/gpu";        MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/half";       MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/fast2";      MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Algorithm = "cn/fast"; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/r";          MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rto";        MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rwz";        MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/xao";        MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/zls";        MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/0";    MinMemGb = 4; MinMemGbW10 = 4; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/tube"; MinMemGb = 4; MinMemGbW10 = 4; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/xhv";  MinMemGb = 4; MinMemGbW10 = 4; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-lite/1";     MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-pico";       MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/0";          MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/arq";        MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/loki";       MinMemGb = 2; MinMemGbW10 = 2; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/wow";        MinMemGb = 1; MinMemGbW10 = 1; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","NVIDIA")}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","NVIDIA")
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

if ($Session.DevicesByTypes.NVIDIA) {$Cuda = Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name}

foreach ($Miner_Vendor in @("AMD","CPU","NVIDIA")) {
    $Session.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Device = $Session.DevicesByTypes.$Miner_Vendor | Where-Object Model -EQ $_.Model
        $Miner_Model = $_.Model

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor} | ForEach-Object {
            $First = $True
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
            $MinMemGb = if ($_.MinMemGbW10 -and $Session.WindowsVersion -ge "10.0.0.0") {$_.MinMemGbW10} else {$_.MinMemGb}
            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or $_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)}

		    foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($Miner_Vendor -ne "NVIDIA" -or $Miner_Model -eq $Session.DevicesByTypes.FullComboModels.NVIDIA)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                        $DeviceParams = Switch ($Miner_Vendor) {
                            "AMD" {"--no-cpu --opencl --opencl-devices=$($Miner_Device.Type_Vendor_Index -join ',') --opencl-platform=$($Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId)"}
                            "CPU" {""} #{"$(if ($Session.Config.CPUMiningThreads -and $Global:GlobalCPUInfo.Threads){"--cpu-max-threads-hint=$([Math]::Ceiling($Session.Config.CPUMiningThreads/$Global:GlobalCPUInfo.Threads*100))"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"}
                            "NVIDIA" {"--no-cpu --cuda --cuda-loader=$CudaLib --cuda-devices=$($Miner_Device.Type_Vendor_Index -join ',') --no-nvml"}
                        }
                    }

                    $Arguments = [PSCustomObject]@{
                        Algorithm    = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}
                        PoolParams   = "-o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --keepalive$(if ($Pools.$Algorithm_Norm.Name -match "NiceHash") {" --nicehash"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})"
                        APIParams    = "--http-enabled --http-host=127.0.0.1 --http-port=`$mport"
                        DeviceParams = $DeviceParams
                        Config = [PSCustomObject]@{
                            "api" = [PSCustomObject]@{
                                "id"           = $null
                                "worker-id"    = $null
                            }
                            "background"   = $false
                            "colors"       = $true
                            "randomx" = [PSCustomObject]@{
                                "init" = -1
                                "numa" = $true
                            }
                            "donate-level" = if ($IsLinux) {1} else {0}
                            "log-file"     = $null
                            "print-time"   = 5
                            "retries"      = 5
                            "retry-pause"  = 1
                        }
                        Vendor  = $Miner_Vendor
                        Params  = $Params
                        HwSig   = if ($Miner_Vendor -eq "CPU") {"$(($Session.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"} else {"$($Miner_Model)-$(($Miner_Device.Type_Vendor_Index | Sort-Object | %{"{0:x}" -f $_}) -join '')"}
                        Threads = if ($Miner_Vendor -eq "CPU") {if ($Session.Config.CPUMiningThreads) {$Session.Config.CPUMiningThreads}  else {$Global:GlobalCPUInfo.Threads}} else {1}
                        Devices = $Miner_Device.Type_Vendor_Index
                        Affinity= if ($Miner_Vendor -eq "CPU" -and $Session.Config.CPUMiningAffinity -ne '') {$Session.Config.CPUMiningAffinity} else {$null}
                    }

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = $Path
					    Arguments      = $Arguments
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "XMRig3"
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
}