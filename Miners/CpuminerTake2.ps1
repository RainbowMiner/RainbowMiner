using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$ManualUri = "https://github.com/Raptor3um/cpuminer-opt/releases"
$Port = "212{0:d2}"
$DevFee = 0.0
$Version = "2.0"

if ($IsLinux) {
    $Path = ".\Bin\CPU-Take2\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx512){'avx512'}elseif($f.avx2 -and $f.sha -and $f.aes){'zen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'}))"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.0-take2/cpuminer-take2-ubuntu16-18.tar.gz"
} else {
    $Path = ".\Bin\CPU-Take2\cpuminer-$($f = $Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'zen'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.0-take2/cpuminer-take2-windows.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "take2"; Params = ""; FaultTolerance = 10; ExtendInterval = 3; ExcludePoolName = "C3pool|MoneroOcean"} #RTM/Take2
)

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "KeysNoGPU"
    CheckSSL = $true
    UseAlgoOverride = $true
    CmdFilter = $true
    CpuParams = $true
    ExtendDefault = 2
    UseExcludePool = $true
    EmitsMaxRej = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-b `$mport -a gr -o stratum+tcp$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)" }
}
