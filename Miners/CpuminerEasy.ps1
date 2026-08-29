using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Path = ".\Bin\CPU-Easy\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx -and $f.aes){'aes-avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.7.0-cpuminereasy/cpuminer-easy-binarium-win_x64.zip"
$ManualUri = "https://github.com/bubasik/cpuminer-easy-binarium/releases"
$Port = "231{0:d2}"
$DevFee = 0.0
$Version = "3.7.0"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Binarium_hash_v1"; Params = ""} #Binarium-V1
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
