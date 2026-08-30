using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Path = ".\Bin\AMD-Lyra2z\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3-sgminerlyra2z/kernel.rar"
$ManualUri = "https://github.com/djm34/sgminer-msvc2015/releases"
$Port = "403{0:d2}"
$DevFee = 1.0
$Version = "0.3"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = "--worksize 32 --intensity 18"}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "AMD"
    SuffixMode = "ListGPU"
    API = "Xgminer"
    NeedsPlatformId = $true
    DevIdProp = "Type_PlatformId_Index"
    EnvVars = @("GPU_FORCE_64BIT_PTR=0")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "--device $($DeviceIDsAll) --api-port `$mport --api-listen -k $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)" }
}
