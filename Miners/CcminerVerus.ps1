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
    $Path = ".\Bin\NVIDIA-CcminerVerus\ccminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.3-ccminerverus/ccminerverus22-3.8.3cuda-linux.7z"
    $Cuda = "10.2"
} else {
    $Path = ".\Bin\NVIDIA-CcminerVerus\ccminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.3-ccminerverus/ccminerverus22-3.8.3cuda-win.7z"
    $Cuda = "8.0"
}
$ManualUri = "https://github.com/monkins1010/ccminer/releases"
$Port = "139{0:d2}"
$DevFee = 0.0
$Version = "3.8.3"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "verus"; Params = "-a verus"; ExtendInterval = 2} #Verushash
)

if (-not $InfoOnly) {
    if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    DevFeeZero = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
