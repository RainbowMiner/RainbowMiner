using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-YesCrypt\ccminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.25-klaust/ccminer-825-yescrypt3-cuda101-linux.7z"
            Cuda = "10.1"
        }
    )
    $Version = "8.25-yescryptv3"
    $ManualUri = "https://github.com/KlausT/ccminer/releases"
} else {
    $Path = ".\Bin\NVIDIA-YesCrypt\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v10-ccmineryescrypt/ccminerKlausTyescryptv10.7z"
            Cuda = "10.0"
        }        
    )
    $Version = "8.21-r18v10"
    $ManualUri = "https://github.com/nemosminer/ccminer-KlausT-8.21-mod-r18-src-fix/releases"
}
$Port = "129{0:d2}"
$DevFee = 0.0

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3} #yescrypt
    #[PSCustomObject]@{MainAlgorithm = "yescryptR8"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3}, #YesctyptR8, CcminerYescryptR8 faster
    [PSCustomObject]@{MainAlgorithm = "yescryptR16"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR16 #Yenten
    [PSCustomObject]@{MainAlgorithm = "yescryptR16v2"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3} #PPN
    [PSCustomObject]@{MainAlgorithm = "yescryptR24"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3} #YescryptR24
    [PSCustomObject]@{MainAlgorithm = "yescryptR32"; Params = ""; ExtendInterval = 2; FaultTolerance = 0.3; MaxRejectedShareRatio = 0.9} #YescryptR32
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
    MakeArgs = { "--no-cpu-verify -N 1 -R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
