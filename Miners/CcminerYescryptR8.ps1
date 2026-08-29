using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-YesCryptR8\ccminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21r17kotov2-ccminerklaust/ccminer-KlausT-8.21-mod-r17-koto-sapling-2.7z"
            Cuda = "9.1"
        }
    )
    $ManualUri = "https://github.com/Kudaraidee/ccminer-KlausT-8.21-mod-koto-sapling-2/releases"
    $Version = "8.21-r17kotov2"
} else {
    $Path = ".\Bin\NVIDIA-YesCryptR8\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21r18v5-ccminerklaust/ccmineryescryptrV5.7z"
            Cuda = "10.1"
        }
    )
    $ManualUri = "https://github.com/Minerx117/ccmineryescryptr8g/releases"
    $Version = "8.21-r18v5"
}

$Port = "137{0:d2}"
$DevFee = 0.0

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = "-a yescryptr16"; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = "-a yescryptr32"; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptR8"; Params = "-a yescryptR8"; ExtendInterval = 2; FaultTolerance = 0.3} #YesctyptR8
    [PSCustomObject]@{MainAlgorithm = "yescryptR8G"; Params = "-a yescrypt"; ExtendInterval = 2; FaultTolerance = 0.3} #YesctyptR8G
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
    HashRateMode = "DayPenalty"
    MaxRejDefault = 0.5
    MiningPriority = 2
    EmitsMaxRej = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "--no-cpu-verify -N 1 -R 1 -b `$mport -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
