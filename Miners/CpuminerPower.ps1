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
    $Path = ".\Bin\CPU-Power\cpuminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4-cpupool/Cpuminer-opt-cpu-pool-v1.4-linux64.tar.gz"
} else {
    $Path = ".\Bin\CPU-Power\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4-cpupool/Cpuminer-opt-cpu-pool-v1.4-win64.zip"
}
$ManualUri = "https://github.com/cpu-pool/cpuminer-opt-cpupower/releases"
$Port = "239{0:d2}"
$DevFee = 0.0
$Version = "1.4"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "cpupower"; Params = ""} #CpuPower (CpuminerRKZ faster)
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = ""; MaxRejectedShareRatio = 0.7} #Yespower2b
    #[PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt
    #[PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8
    #[PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower
    [PSCustomObject]@{MainAlgorithm = "yespowerinter"; Params = ""} #Yespower Intercoin (ITC)
    [PSCustomObject]@{MainAlgorithm = "yespowerlitb"; Params = ""} #Yespower LightBit (LITB)
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16
    #[PSCustomObject]@{MainAlgorithm = "yespowersugar"; Params = ""} #Yespower Sugar (SUGAR)
    #[PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = ""} #Yespower Uranium-X (URX)
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
