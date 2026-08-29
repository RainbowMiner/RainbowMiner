using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/brian112358/ccminer-bsha3/releases"
$Port = "143{0:d2}"
$DevFee = 0.0
$Cuda = "9.1"
$Version = "1.0.1"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerSha3d\ccminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.1-ccminersha3d/ccminersha3d-v1.0.1-linux.7z"
} else {
    $Path = ".\Bin\NVIDIA-CcminerSha3d\ccminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.1-ccminersha3d/ccminersha3d-v1.0.1-win.7z"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "sha3d"; Params = "-a keccak -i 27"; ExtendInterval = 2} #SHA3d
)

if (-not $InfoOnly) {
    if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
