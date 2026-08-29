using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

if ($IsLinux) {
    $Path = ".\Bin\CPU-rkz\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.sse2 -and $f.aes){'aes-sse2'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.9.7c-cpuminerrkz/cpuminer-RKZ-3.9.7c-ubuntu18.7z"
} else {
    $Path = ".\Bin\CPU-rkz\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'sha-avx2'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.9.7c-cpuminerrkz/cpuminer-RKZ-3.9.7c-win64.7z"
}
$ManualUri = "https://github.com/patrykwnosuch/cpuminer-RKZ/releases"
$Port = "242{0:d2}"
$DevFee = 0.0
$Version = "3.9.7c"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "argon2d250"; Params = ""} #Argon2d-crds
    #[PSCustomObject]@{MainAlgorithm = "argon2d500"; Params = ""} #Argon2d-dyn
    #[PSCustomObject]@{MainAlgorithm = "argon2d4096"; Params = ""} #Argon2d-uis
    [PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""} #CPUpower
    [PSCustomObject]@{MainAlgorithm = "m7m"; Params = ""} #m7m (fastest)
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8
    #[PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerlitb"; Params = ""} #YespowerLITB
    #[PSCustomObject]@{MainAlgorithm = "yespowerltncg"; Params = ""} #YespowerLTNCG
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16-ynt (CpuminerRplant faster)
    #[PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = ""} #YespowerURX
)

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "ListCPU"
    CheckSSL = $true
    CpuParams = $true
    ExtendDefault = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-b `$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)" }
}
