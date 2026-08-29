using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Path = ".\Bin\CPU-Multi\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}elseif($f.sse42){'sse42'}else{'sse2'})).exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.6.3-cpuminermulti/cpuminer-multi-1.3.6.3.7z"
$ManualUri = "https://github.com/tpruvot/cpuminer-multi/releases"
$Port = "213{0:d2}"
$DevFee = 0.0
$Version = "1.3.6.3"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "allium"; Params = ""} #allium, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "axiom"; Params = ""} #axiom
    #[PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #BMW
    #[PSCustomObject]@{MainAlgorithm = "drop"; Params = ""} #Drop
    #[PSCustomObject]@{MainAlgorithm = "fresh"; Params = ""} #Fresh
    #[PSCustomObject]@{MainAlgorithm = "heavy"; Params = ""} #Heavy
    #[PSCustomObject]@{MainAlgorithm = "jha"; Params = ""} #JHA
    #[PSCustomObject]@{MainAlgorithm = "luffa"; Params = ""} #Luffa
    #[PSCustomObject]@{MainAlgorithm = "pentablake"; Params = ""} #Pentablake
    #[PSCustomObject]@{MainAlgorithm = "phi2"; Params = ""} #PHI2
    #[PSCustomObject]@{MainAlgorithm = "pluck"; Params = ""} #Pluck
    [PSCustomObject]@{MainAlgorithm = "rfv2"; Params = ""} #Rainforest2
    [PSCustomObject]@{MainAlgorithm = "scryptjane:16"; Params = ""} #ScryptJane16
    [PSCustomObject]@{MainAlgorithm = "scrypt:2048"; Params = ""} #ScryptN
    #[PSCustomObject]@{MainAlgorithm = "shavite3"; Params = ""} #SHAvite3
    #[PSCustomObject]@{MainAlgorithm = "skein2"; Params = ""} #Skein2
    #[PSCustomObject]@{MainAlgorithm = "scrypt:1048576"; Params = ""} #ScryptN2, CpuminerVerium faster
    #[PSCustomObject]@{MainAlgorithm = "x12"; Params = ""} #X12
    #[PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = ""} #Yescrypt, CpuminerJayddee faster
    #[PSCustomObject]@{MainAlgorithm = "zr5"; Params = ""} #ZR5
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
