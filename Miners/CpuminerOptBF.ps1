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
    $Path = ".\Bin\CPU-OptBF\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'}))"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.12-cpumineropt/cpuminer-opt-v3.8.12-bf-linux.7z"
} else {
    $Path = ".\Bin\CPU-OptBF\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.12-cpumineropt/cpuminer-opt-v3.8.12-bf-win64.zip"
}
$ManualUri = "https://github.com/bellflower2015/cpuminer-opt/releases"
$Port = "204{0:d2}"
$DevFee = 0.0
$Version = "3.8.12"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower, CpuminerYespower faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr24"; Params = ""} #YescryptR24, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32, CpuminerRplant same but also linux
    #[PSCustomObject]@{MainAlgorithm = "yespower05r16"; Params = ""} #yespowerR16 (old yenten)
    [PSCustomObject]@{MainAlgorithm = "yespowerr8"; Params = ""} #YespowerR8
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "yespowerr24"; Params = ""} #YespowerR24
    [PSCustomObject]@{MainAlgorithm = "yespowerr32"; Params = ""} #YespowerR32
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
    MakeArgs = { "-b `$mport -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -R 10 -r 4$($DeviceParams) $($_.Params)" }
}
