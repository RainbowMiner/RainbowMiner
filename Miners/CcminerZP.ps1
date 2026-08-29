using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Port = "144{0:d2}"
$DevFee = 0.0
$Cuda = "9.0"
$Version = "8.23"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerZP\ccminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.23-zp/ZenProtocol-ccminer-8.23-x64.tar.gz"
} else {
    $Path = ".\Bin\NVIDIA-CcminerZP\ccminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.23-zp/ZenProtocol-ccminer-8.23-Winx64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "zenprotocol"; Params = "-N 1"} #ZenProtocol/SHA3
)

if (-not $InfoOnly) {
    if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    ArchIn = @("Other","Pascal")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
