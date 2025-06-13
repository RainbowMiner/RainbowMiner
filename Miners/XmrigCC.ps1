using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $Global:DeviceCache.DevicesByTypes.CPU -and -not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No GPU present in system

$ManualUri = "https://github.com/Bendr0id/xmrigCC/releases"
$Port = "376{0:d2}"
$Version = "3.4.6"
$DevFee = 0.0

$UriCuda = $null
$Uri     = $null
$CudaLib = $null
$CudaData= $null

$PathUriLib  = ".\Bin\ANY-XmrigCC\_urilib.json"
$PathCudaLib = $null

if ($IsLinux) {

    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
        if ($Global:GlobalCPUInfo.Architecture -eq 8) {
            $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.4.6-xmrigcc/xmrigcc-3.4.6-armv8.7z"
        }
    } else {
        if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.25")) {return}

        $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.4.6-xmrigcc/xmrigcc-3.4.6-bionic-x64.7z"

        $CudaData = @(
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_9-linux.7z"
                Cuda = "12.9"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_8-linux.7z"
                Cuda = "12.8"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_6-linux.7z"
                Cuda = "12.6"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_5-linux.7z"
                Cuda = "12.5"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_4-linux.7z"
                Cuda = "12.4"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_3-linux.7z"
                Cuda = "12.3"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_2-linux.7z"
                Cuda = "12.2"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_1-linux.7z"
                Cuda = "12.1"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_0-linux.7z"
                Cuda = "12.0"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_8-linux.7z"
                Cuda = "11.8"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_7-linux.7z"
                Cuda = "11.7"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_6-linux.7z"
                Cuda = "11.6"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_5-linux.7z"
                Cuda = "11.5"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_4-linux.7z"
                Cuda = "11.4"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_3-linux.7z"
                Cuda = "11.3"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_2-linux.7z"
                Cuda = "11.2"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_1-linux.7z"
                Cuda = "11.1"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_0-linux.7z"
                Cuda = "11.0"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda10_2-linux.7z"
                Cuda = "10.2"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda10_1-linux.7z"
                Cuda = "10.1"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda10_0-linux.7z"
                Cuda = "10.0"
            },
            [PSCustomObject]@{
                Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda9_2-linux.7z"
                Cuda = "9.2"
            }
        )
    }

    $Path    = ".\Bin\ANY-XmrigCC\xmrigDaemon"
    $CudaLib = "libxmrig-cuda.so"
    $Executables = @("xmrigMiner")
} else {

    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.4.6-xmrigcc/xmrigcc-3.4.6-msvc-win64.7z"

    $CudaData = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_9-win64.7z"
            Cuda = "12.9"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_8-win64.7z"
            Cuda = "12.8"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_6-win64.7z"
            Cuda = "12.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_5-win64.7z"
            Cuda = "12.5"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_4-win64.7z"
            Cuda = "12.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_3-win64.7z"
            Cuda = "12.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_2-win64.7z"
            Cuda = "12.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_1-win64.7z"
            Cuda = "12.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda12_0-win64.7z"
            Cuda = "12.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_8-win64.7z"
            Cuda = "11.8"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_7-win64.7z"
            Cuda = "11.7"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_6-win64.7z"
            Cuda = "11.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_5-win64.7z"
            Cuda = "11.5"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_4-win64.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_3-win64.7z"
            Cuda = "11.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_2-win64.7z"
            Cuda = "11.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_1-win64.7z"
            Cuda = "11.1"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda11_0-win64.7z"
            Cuda = "11.0"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v6.22.1-xmrigcuda/xmrig-cuda-6.22.1-cuda10_2-win64.7z"
            Cuda = "10.2"
        }
    )

    $Path    = ".\Bin\ANY-XmrigCC\xmrigDaemon.exe"
    $CudaLib = "xmrig-cuda.dll"
    $Executables = @("xmrigMiner.exe")
}

if ($Uri -eq $null) {return}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwa";              MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/chukwav2";            MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/ninja";               MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "argon2/wrkz";                MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "cn/upx2";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/0";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/1";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/2";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/ccx";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/double";                  MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/fast";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/half";                    MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/r";                       MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rto";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/rwz";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/xao";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn/zls";                     MinMemGb = 1.5; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/0";                 MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/tube";              MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-heavy/xhv";               MinMemGb = 3.3; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-lite/0";                  MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-lite/1";                  MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-pico";                    MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "cn-pico/tlo";                MinMemGb = 1;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "ghostrider";                 MinMemGb = 1;   Params = ""; ExtendInterval = 3; Vendor = @("CPU"); FaultTolerance = 8}
    [PSCustomObject]@{MainAlgorithm = "kawpow";        DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "kawpow2g";      DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "kawpow"}
    [PSCustomObject]@{MainAlgorithm = "kawpow3g";      DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "kawpow"}
    [PSCustomObject]@{MainAlgorithm = "kawpow4g";      DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "kawpow"}
    [PSCustomObject]@{MainAlgorithm = "kawpow5g";      DAG = $true; MinMemGb = 3;   Params = ""; ExtendInterval = 2; Vendor = @("AMD","INTEL","NVIDIA"); Algorithm = "kawpow"}
    [PSCustomObject]@{MainAlgorithm = "mike";                       MinMemGb = 1;   Params = ""; ExtendInterval = 3; Vendor = @("CPU"); FaultTolerance = 8; Algorithm = "ghostrider/mike"}
    [PSCustomObject]@{MainAlgorithm = "rx/0";                       MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/arq";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 3; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/grft";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")} #CUDA Plugin v6.12.0 doesn't support GRFT, v6.15.0 has memory bug
    [PSCustomObject]@{MainAlgorithm = "rx/sfx";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/tuske";                   MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "rx/wow";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
    [PSCustomObject]@{MainAlgorithm = "rx/xdag";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "rx/xeq";                     MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("CPU")}
    [PSCustomObject]@{MainAlgorithm = "rx/yada";                    MinMemGb = 2.0; Params = ""; ExtendInterval = 2; Vendor = @("AMD","CPU","INTEL","NVIDIA")}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD","CPU","INTEL","NVIDIA","ARMCPU")
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

$Cuda = $null
if ($Session.Config.CUDAVersion) {
    for($i=0;$i -lt $CudaData.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $CudaData[$i].Cuda -Warning $(if (($i -lt $CudaData.Count-1) -or -not $Global:DeviceCache.DevicesByTypes.NVIDIA) {""}else{$Name})) {
            $UriCuda = $CudaData[$i].Uri
            $Cuda    = $CudaData[$i].Cuda
        }
    }
}

if ($IsWindows -and -not $Cuda) {
    $UriCuda = ($CudaData | Select-Object -Last 1).Uri
}

if ($UriCuda -and $CudaLib) {
    $PathCudaLib = Join-Path ".\Bin\ANY-XmrigCC" $CudaLib
    $PathCudaLib_Update = $true
    if (Test-Path $PathUriLib) {
        try {
            $UriLib_Current = Get-ContentByStreamReader $PathUriLib | ConvertFrom-Json -ErrorAction Stop
            if ($UriLib_Current.URI -ne $UriCuda) {
                if (Test-Path $PathCudaLib) {
                    Remove-Item $PathCudaLib -Force
                }
            } else {
                $PathCudaLib_Update = $false
            }
        } catch {
        }
    }
    if ($PathCudaLib_Update -and (Test-Path (Split-Path $PathUriLib))) {
        ConvertTo-Json ([PSCustomObject]@{URI = $UriCuda}) | Set-Content $PathUriLib
    }
}

foreach ($Miner_Vendor in @("AMD","CPU","INTEL","NVIDIA")) {
    $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Vendor -ne "NVIDIA" -or $Cuda} | Select-Object Vendor, Model -Unique | ForEach-Object {
        $Miner_Model = $_.Model
        $Device = $Global:DeviceCache.DevicesByTypes.$Miner_Vendor | Where-Object {$_.Model -eq $Miner_Model}

        $Miner_PlatformId = $null
        if ($Miner_Vendor -in @("AMD","INTEL")) {
            $Miner_PlatformId = $Device | Select-Object -ExpandProperty PlatformId -Unique
            if ($Miner_PlatformId -isnot [int]) {return}
        }

        $Commands | Where-Object {$_.Vendor -icontains $Miner_Vendor -and ($_.Vendor -ne "NVIDIA" -or $_.MainAlgorithm -ne "rx/grft" -or $Uri -match "\ddev") -and ($IsWindows -or $_.MainAlgorithm -ne "astrobwt/v2")} | ForEach-Object {
            $First = $True

            $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm}

            $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

            $All_Algorithms = if ($Miner_Vendor -eq "CPU") {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")} else {@($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")}

            $ByParameters = $_.ByParameters

		    foreach($Algorithm_Norm in $All_Algorithms) {
			    if (-not $Pools.$Algorithm_Norm.Host) {continue}

                $MinMemGB = if ($_.DAG) {Get-EthDAGSize -CoinSymbol $Pools.$Algorithm_Norm.CoinSymbol -Algorithm $Algorithm_Norm_0 -Minimum $_.MinMemGb} else {$_.MinMemGb}
                $Miner_Device = $Device | Where-Object {$Miner_Vendor -eq "CPU" -or (Test-VRAM $_ $MinMemGb)}

			    if ($Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Host -notmatch $_.ExcludePoolName)) {
                    if ($First) {
                        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                        $First = $false
                        $CPUThreads = $null
                        $CPUAffinity = $null
                        $DeviceCodec = $null

                        $DeviceParams = if ($Miner_Vendor -eq "CPU") {
                            $DeviceCodec = "cpu"
                            $CPUThreads = if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads)  {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Threads}  elseif ($Session.Config.Miners."$Name-CPU".Threads)  {$Session.Config.Miners."$Name-CPU".Threads}  elseif ($Session.Config.CPUMiningThreads)  {$Session.Config.CPUMiningThreads}
                            $CPUAffinity= if ($Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity) {$Session.Config.Miners."$Name-CPU-$Algorithm_Norm_0".Affinity} elseif ($Session.Config.Miners."$Name-CPU".Affinity) {$Session.Config.Miners."$Name-CPU".Affinity} elseif ($Session.Config.CPUMiningAffinity) {$Session.Config.CPUMiningAffinity}
                            "$(if ($ByParameters -and $CPUThreads){" -t $CPUThreads"})$(if ($ByParameters -and $CPUAffinity){" --cpu-affinity=$CPUAffinity"})"
                        } elseif ($Miner_Vendor -eq "AMD" -or $Miner_Vendor -eq "INTEL" -or $_.UseOpenCL) {
                            $DeviceCodec = "opencl"
                            "--opencl --opencl-devices=$($Miner_Device.Type_PlatformId_Index -join ',') --opencl-platform=$($Miner_PlatformId) --no-cpu"
                        } else {
                            $DeviceCodec = "cuda"
                            "--cuda --cuda-loader=$CudaLib --cuda-devices=$($Miner_Device.Type_Vendor_Index -join ',') --no-nvml --no-cpu"
                        }
                    }

                    if ($ByParameters) {
                        $Arguments = "-a $($Algorithm) -o $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.SSL) {" --tls"})$(if ($Pools.$Algorithm_Norm.Host -match "Nicehash") {" --nicehash"}) --donate-level=0 --keepalive --http-enabled --http-host=127.0.0.1 --http-port=`$mport$($DeviceParams) $($_.Params)"
                    } else {
                        $Pool_CoinSymbol = if ($Pools.$Algorithm_Norm.CoinSymbol -in @("XMR","SUMO","ARQ","GRFT","KVA","RVN","WOW","XEQ","ZEPH","Townforge")) {$Pools.$Algorithm_Norm.CoinSymbol} else {$null}

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
                                    "coin"      = $Pool_CoinSymbol
                                    "url"       = "$($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port)"
                                    "user"      = $Pools.$Algorithm_Norm.User
                                    "pass"      = if ($Pools.$Algorithm_Norm.Pass) {$Pools.$Algorithm_Norm.Pass} else {"x"}
                                    "rig-id"    = $Pools.$Algorithm_Norm.Worker
                                    "nicehash"  = $Pools.$Algorithm_Norm.Host -match "NiceHash"
                                    "keepalive" = $true
                                    "enabled"   = $true
                                    "tls"       = $Pools.$Algorithm_Norm.SSL
                                }
                            )
                            Vendor  = $Miner_Vendor
                            Params  = "$($_.Params)"
                            HwSig   = if ($Miner_Vendor -eq "CPU") {"$(($Global:DeviceCache.DevicesByTypes.CPU | Measure-Object).Count)x$($Global:GlobalCPUInfo.Name -replace "(\(R\)|\(TM\)|CPU|Processor)" -replace "[^A-Z0-9]")"} else {"$($Miner_Model)-$(($Miner_Device.Type_Vendor_Index | Sort-Object | %{"{0:x}" -f $_}) -join '')"}
                            Threads = if ($Miner_Vendor -eq "CPU") {if ($CPUThreads) {$CPUThreads} else {$Global:GlobalCPUInfo.Cores}} else {1}
                            Devices = $Miner_Device.Type_Vendor_Index
                            Affinity= $CPUAffinity
                            Codec   = $DeviceCodec
                        }
                    }

				    [PSCustomObject]@{
					    Name             = $Miner_Name
					    DeviceName       = $Miner_Device.Name
					    DeviceModel      = $Miner_Model
					    Path             = $Path
					    Arguments        = $Arguments
					    HashRates        = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					    API              = "XMRig6"
					    Port             = $Miner_Port
					    Uri              = $Uri
                        FaultTolerance   = $_.FaultTolerance
					    ExtendInterval   = $_.ExtendInterval
                        Penalty          = 0
					    DevFee           = $DevFee
					    ManualUri        = $ManualUri
                        Version          = $Version
                        PowerDraw        = 0
                        BaseName         = $Name
                        BaseAlgorithm    = $Algorithm_Norm_0
                        Benchmarked      = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                        LogFile          = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
                        ExcludePoolName  = $_.ExcludePoolName
                        PrerequisitePath = $PathCudaLib
                        PrerequisiteURI  = $UriCuda
                        PrerequisiteMsg  = "Downloading Xmrig support files in the background, please wait!"
                        MultiProcess     = 1
                        Executables      = $Executables
				    }
			    }
		    }
        }
    }
}
