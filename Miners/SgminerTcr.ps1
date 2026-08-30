using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

if ($IsLinux) {
    $Path = ".\Bin\AMD-SgminerTCR\sgminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.4-sgminertcr/sgminertcr-v0.1.4-linux.7z"
    $Version = "0.1.4"
} else {
    $Path = ".\Bin\AMD-SgminerTCR\sgminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.7-sgminertcr/sgminertcr-v0.1.7-win64.zip"
    $Version = "0.1.7"
}
$ManualUri = "https://github.com/tecracoin/sgminer/releases"
$Port = "414{0:d2}"
$DevFee = 0.0

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; Params = "--kernel mtp --worksize 64 -I 20"; ParamsVega = "--kernel mtp_vega --worksize 256 -I 23"}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "AMD"
    SuffixMode = "ListGPU"
    API = "Xgminer"
    NeedsPlatformId = $true
    DevIdProp = "Type_PlatformId_Index"
    EnvVars = @("GPU_FORCE_64BIT_PTR=0","GPU_MAX_SINGLE_ALLOC_PERCENT=100")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "$($_."Params$(if ($Miner_Model -match "(gfx900|vega)") {"Vega"})") --device $($DeviceIDsAll) --api-port `$mport --api-listen -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-platform $($Miner_PlatformId)" }
}
