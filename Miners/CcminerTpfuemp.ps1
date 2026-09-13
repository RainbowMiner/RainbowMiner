using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/tpfuemp/ccminer-tpfuemp/releases"
$Port = "144{0:d2}"
$DevFee = 0.0
$Cuda = "11.8"
$Version = "v2026.07.2"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerTpfuemp\ccminer"
    $Uri = "https://github.com/tpfuemp/ccminer-tpfuemp/releases/download/v2026.07.2/ccminer-tpfuemp-2026.07.2-linux-x64.tar.gz"
} else {
    $Path = ".\Bin\NVIDIA-CcminerTpfuemp\ccminer.exe"
    $Uri = "https://github.com/tpfuemp/ccminer-tpfuemp/releases/download/v2026.07.2/ccminer-tpfuemp-2026.07.2-windows-x64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = "-a allium "; ExtendInterval = 2} #allium
    [PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = "-a argon2d500 "; ExtendInterval = 2} #argon2d500
    [PSCustomObject]@{MainAlgorithm = "argon2d1000"; Params = "-a argon2d1000 "; ExtendInterval = 2} #argon2d1000
    [PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = "-a argon2d4096 "; ExtendInterval = 2} #argon2d4096
    [PSCustomObject]@{MainAlgorithm = "argon2d16000"; Params = "-a argon2d16000 "; ExtendInterval = 2} #argon2d16000
    [PSCustomObject]@{MainAlgorithm = "balloon"; Params = "-a balloon "; ExtendInterval = 2} #balloon
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = "-a bmw "; ExtendInterval = 2} #bmw
    [PSCustomObject]@{MainAlgorithm = "bmw512"; Params = "-a bmw512 "; ExtendInterval = 2} #bmw512
    [PSCustomObject]@{MainAlgorithm = "curvehash"; Params = "-a curvehash "; ExtendInterval = 2} #curvehash
    [PSCustomObject]@{MainAlgorithm = "evrprogpow"; Params = "-a evrprogpow "; ExtendInterval = 2} #evrprogpow
    [PSCustomObject]@{MainAlgorithm = "firopow"; Params = "-a firopow "; ExtendInterval = 2} #firopow
    [PSCustomObject]@{MainAlgorithm = "hoohashpepew"; Params = "-a pepew "; ExtendInterval = 2} #hoohashpepew
    [PSCustomObject]@{MainAlgorithm = "kawpow"; Params = "-a kawpow "; ExtendInterval = 2} #kawpow
    [PSCustomObject]@{MainAlgorithm = "meowpow"; Params = "-a meowpow "; ExtendInterval = 2} #meowpow
    [PSCustomObject]@{MainAlgorithm = "meraki"; Params = "-a meraki "; ExtendInterval = 2} #meraki
    [PSCustomObject]@{MainAlgorithm = "rinhash"; Params = "-a rinhash "; ExtendInterval = 2} #rinhash
    [PSCustomObject]@{MainAlgorithm = "sha256csm"; Params = "-a sha256csm "; ExtendInterval = 2} #sha256csm
    [PSCustomObject]@{MainAlgorithm = "sha3t"; Params = "-a sha3t "; ExtendInterval = 2} #SHA3t
    [PSCustomObject]@{MainAlgorithm = "sha512256d"; Params = "-a sha512256d "; ExtendInterval = 2} #sha512256d
    [PSCustomObject]@{MainAlgorithm = "skydoge"; Params = "-a skydoge "; ExtendInterval = 2} #skydoge
    [PSCustomObject]@{MainAlgorithm = "soterg"; Params = "-a soterg "; ExtendInterval = 2} #soterg
    [PSCustomObject]@{MainAlgorithm = "whirlpoolx2"; Params = "-a whirlpoolx2 "; ExtendInterval = 2} #whirlpoolx2
    [PSCustomObject]@{MainAlgorithm = "x25x"; Params = "-a x25x "; ExtendInterval = 2} #x25x
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = "-a yescrypt "; ExtendInterval = 2} #yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = "-a yescryptr8 "; ExtendInterval = 2} #yescryptr8
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = "-a yescryptr16 "; ExtendInterval = 2} #yescryptr16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = "-a yescryptr32 "; ExtendInterval = 2} #yescryptr32
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
