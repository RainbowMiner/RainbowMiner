using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$ManualUri = "https://github.com/xmrig/xmrig/releases"
$Port = "303{0:d2}"
$Version = "6.16.2"
$DevFee = 0.0

if ($IsLinux) {

    if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.25")) {return}

    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_5-x64.7z"
            Cuda = "11.5"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_4-x64.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_3-x64.7z"
            Cuda = "11.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_2-x64.7z"
            Cuda = "11.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_1-x64.7z"
            Cuda = "11.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda11_0-x64.7z"
            Cuda = "11.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda10_2-x64.7z"
            Cuda = "10.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda10_1-x64.7z"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda10_0-x64.7z"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-bionic-cuda9_2-x64.7z"
            Cuda = "9.2"
        }
    )

    $Path    = ".\Bin\ANY-Xmrig\xmrig"
    $PathMO  = ".\Bin\Any-Xmrig\xmrig-mo"
    $CudaLib = "libxmrig-cuda.so"
} else {
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_5-win64.7z"
            Cuda = "11.5"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_4-win64.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_3-win64.7z"
            Cuda = "11.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_2-win64.7z"
            Cuda = "11.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_1-win64.7z"
            Cuda = "11.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda11_0-win64.7z"
            Cuda = "11.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda10_2-win64.7z"
            Cuda = "10.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda10_1-win64.7z"
            Cuda = "10.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda10_0-win64.7z"
            Cuda = "10.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda9_2-win64.7z"
            Cuda = "9.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda9_1-win64.7z"
            Cuda = "9.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda9_0-win64.7z"
            Cuda = "9.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.16.2-xmrig/xmrig-6.16.2.1-msvc-cuda8_0-win64.7z"
            Cuda = "8.0"
        }
    )

    $Path    = ".\Bin\ANY-Xmrig\xmrig.exe"
    $PathMO  = ".\Bin\ANY-Xmrig\xmrig-mo.exe"
    $CudaLib = "xmrig-cuda.dll"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

if ($Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $CudaLib) {return}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwa";              MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwav2";              MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/wrkz";                MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "astrobwt";                   MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    #[PSCustomObject]@{MainAlgorithm = "cn/1";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    #[PSCustomObject]@{MainAlgorithm = "cn/2";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/ccx";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/double";                  MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/half";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/fast";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/r";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rto";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rwz";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/upx2";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/xao";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/zls";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/0";                 MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/tube";              MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/xhv";               MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-lite/1";                  MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-pico";                    MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-pico/tlo";                MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "ghostrider";                 MinMemGb = 1;   Params = ""; ExtendInterval = 3; Vendor = @("CPU"); FaultTolerance = 8; UseMO = $true}
    [PSCustomObject]@{MainAlgorithm = "kawpow";        DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/0";                       MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/arq";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/grft";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")} #CUDA Plugin v6.12.0 doesn't support GRFT, v6.15.0 has memory bug
    [PSCustomObject]@{MainAlgorithm = "rx/keva";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    #[PSCustomObject]@{MainAlgorithm = "rx/loki";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/sfx";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/wow";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","INTEL","NVIDIA")
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
if ($Session.Config.CUDAVersion) {
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if (($i -lt $UriCuda.Count-1) -or -not $Global:DeviceCache.DevicesByTypes.NVIDIA) {""}else{$Name})) {
            $Uri = $UriCuda[$i].Uri
            $Cuda= $UriCuda[$i].Cuda
        }
    }
}

if (-not $Cuda) {
    $Uri = ($UriCuda | Select-Object -Last 1).Uri
}

foreach ($Miner_Vendor in @("AMD","CPU","INTEL","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor.Where({$_.Model -eq $Miner_Model})

        $Commands.Where({$_.Vendor -icontains $Miner_Vendor -and ($_.Vendor -ne "NVIDIA" -or $_.MainAlgorithm -ne "rx/grft" -or $Uri -match "\ddev")}).ForEach({
            $First = $True
            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm_0.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}

            $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or (Test-VRAM $_ $MinMemGb)}

            #if ($Algorithm_Norm_0 -eq "Take2" -and $Global:GlobalCPUInfo.Cores -lt 4 -and ($Global:DeviceCache.Devices | Where-Object Type -eq "Gpu" | Measure-Object).Count) {$Miner_Device = $null}

            $All_Algorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

            $ByParameters = $_.ByParameters

		    foreach($Algorithm_Norm in $All_Algorithms) {
			    if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                        $CPUThreads = $null
                        $CPUAffinity = $null
                        $DeviceParams = Switch ($Miner_Vendor) {
                            "AMD" {"--opencl --opencl-devices=$($Miner_Device.Type_Vendor_Index -join ',') --opencl-platform=$($Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId) --no-cpu";break}
                            "CPU" {
                                $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                                $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
                                "$(if ($ByParameters -and $CPUThreads){" -t $CPUThreads"})$(if ($ByParameters -and $CPUAffinity){" --cpu-affinity=$CPUAffinity"})"
                                break
                            } #{"$(if ($Session.Config.CPUMiningThreads -and $Global:GlobalCPUInfo.Threads){"--cpu-max-threads-hint=$([Math]::Ceiling($Session.Config.CPUMiningThreads/$Global:GlobalCPUInfo.Threads*100))"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"}
                            "INTEL" {"--opencl --opencl-devices=$($Miner_Device.Type_Vendor_Index -join ',') --opencl-platform=$($Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId) --no-cpu";break}
                            "NVIDIA" {"--cuda --cuda-loader=$CudaLib --cuda-devices=$($Miner_Device.Type_Vendor_Index -join ',') --no-nvml --no-cpu";break}
                        }
                    }

                    $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

                    $UseMO = $_.UseMO -and $Pools.$Algorithm_Norm.Name -match "^MoneroOcean"

                    if ($ByParameters) {
                        $Arguments = "-a $($Algorithm) -o $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})$(if ($Pools.$Algorithm_Norm.Name -match "Nicehash") {" --nicehash"}) --donate-level=0 --keepalive --http-enabled --http-host=127.0.0.1 --http-port=`$mport$($DeviceParams) $($_.Params)"
                    } else {
                        $Arguments = [PSCustomObject]@{
                            Algorithm    = $Algorithm
                            APIParams    = "--http-enabled --http-host=127.0.0.1 --http-port=`$mport"
                            DeviceParams = $DeviceParams
                            Config = [PSCustomObject]@{
                                "api" = [PSCustomObject]@{
                                    "id"           = $null
                                    "worker-id"    = $null
                                }
                                "background" = $false
                                "colors"     = $true
                                "randomx" = [PSCustomObject]@{
                                    "init" = -1
                                    "numa" = $true
                                }
                                "donate-level" = 0
                                "log-file"     = $null
                                "print-time"   = 5
                                "retries"      = 5
                                "retry-pause"  = 1
                            }
                            Pools = @(
                                [PSCustomObject]@{
                                    "algo"      = $Algorithm
                                    "coin"      = $null
                                    "url"       = "$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                                    "user"      = $Pools.$Algorithm_Norm.User
                                    "pass"      = if ($Pools.$Algorithm_Norm.Pass) {$Pools.$Algorithm_Norm.Pass} else {"x"}
                                    "rig-id"    = $Pools.$Algorithm_Norm.Worker
                                    "nicehash"  = $Pools.$Algorithm_Norm.Name -match "NiceHash"
                                    "keepalive" = $true
                                    "enabled"   = $true
                                    "tls"       = $Pools.$Algorithm_Norm.SSL
                                }
                            )
                            Vendor  = $Miner_Vendor
                            Params  = $Params
                            HwSig   = if ($Miner_Vendor -eq "CPU") {"$(($Global:DeviceCache.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"} else {"$($Miner_Model)-$(($Miner_Device.Type_Vendor_Index | Sort-Object | %{"{0:x}" -f $_}) -join '')"}
                            Threads = if ($Miner_Vendor -eq "CPU") {if ($CPUThreads) {$CPUThreads} else {$Global:GlobalCPUInfo.Cores}} else {1}
                            Devices = $Miner_Device.Type_Vendor_Index
                            Affinity= $CPUAffinity
                        }
                        if ($UseMO) {
                            $Arguments.Config | Add-Member @{
                                                    "rebench-algo" = $false
                                                    "bench-algo-time" = 0
                                                    "algo-min-time" = 86400
                                                    "algo-perf"    = [PSCustomObject]@{
                                                        "cn/0"= 0
                                                        "cn/1"= 0
                                                        "cn/2"= 0
                                                        "cn/r"= 0
                                                        "cn/fast"= 0
                                                        "cn/half"= 0
                                                        "cn/xao"= 0
                                                        "cn/rto"= 0
                                                        "cn/rwz"= 0
                                                        "cn/zls"= 0
                                                        "cn/double"= 0
                                                        "cn/ccx"= 0
                                                        "cn-lite/0"= 0
                                                        "cn-lite/1"= 0
                                                        "cn-heavy/xhv"= 0
                                                        "cn-pico"= 0
                                                        "cn-pico/tlo"= 0
                                                        "cn/gpu"= 0
                                                        "rx/0"= 0
                                                        "rx/arq"= 0
                                                        "rx/graft"= 0
                                                        "rx/sfx"= 0
                                                        "panthera"= 0
                                                        "argon2/chukwav2"= 0
                                                        "astrobwt"= 0
                                                        "kawpow"= 0
                                                        "ghostrider" = 0
                                                    }
                                                } -Force
                        }
                    }

				    [PSCustomObject]@{
					    Name           = $Miner_Name
					    DeviceName     = $Miner_Device.Name
					    DeviceModel    = $Miner_Model
					    Path           = if ($UseMO) {$PathMO} else {$Path}
					    Arguments      = $Arguments
					    HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API            = "XMRig6"
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
                        Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				    }
			    }
		    }
        })
    }
}