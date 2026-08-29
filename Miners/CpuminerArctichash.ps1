using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Path = ".\Bin\CPU-ArcticHash\cpuminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3.7.1-cpuminerarctichash/cpuminer-arctichash-v1.3.7.1.7z"
$ManualUri = ""
$Port = "245{0:d2}"
$DevFee = 0.0
$Version = "1.3.7.1"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "arctichash"; Params = ""} #Arctichash
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
