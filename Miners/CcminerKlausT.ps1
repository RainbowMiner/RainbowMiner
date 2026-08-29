using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/KlausT/ccminer/releases"
$Port = "140{0:d2}"
$DevFee = 0.0
$Version = "8.26x3"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-KlausT\ccminer"
    $UriCuda = @(
            [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda118-linux.7z"
            Cuda = "11.8"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda116-linux.7z"
            Cuda = "11.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda114-linux.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda102-linux.7z"
            Cuda = "10.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-KlausT\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda118-x64.7z"
            Cuda = "11.8"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda116-x64.7z"
            Cuda = "11.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x3-cuda114-x64.7z"
            Cuda = "11.4"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.26-klaust/ccminerklaust-826x2-cuda102-x64.7z"
            Cuda = "10.2"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "bitcoin"; Params = ""; ExtendInterval = 2} #SHA256
    [PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""; ExtendInterval = 2} #MyriadGroestl
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""; ExtendInterval = 3} #Neoscrypt
    [PSCustomObject]@{MainAlgorithm = "neoscrypt-xaya"; Params = ""; ExtendInterval = 3} #Neoscrypt-Xaya
    [PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""; ExtendInterval = 2} #Qubit
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = ""; ExtendInterval = 2} #X17
)

if (-not $InfoOnly) {
    $Cuda = $null
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
        }
    }
    
    if (-not $Cuda) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    DevFeeZero = $true
    MiningPriority = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)" }
}
