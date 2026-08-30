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
    $Path = ".\Bin\AMD-Nsgminer\nsgminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4-nsgminer/nsgminer-lin64-0.9.4.7z"
} else {
    $Path = ".\Bin\AMD-Nsgminer\nsgminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.9.4-nsgminer/nsgminer-win64-0.9.4.zip"
}
$ManualUri = "https://github.com/ghostlander/nsgminer/releases"
$Port = "406{0:d2}"
$DevFee = 0.0
$Version = "0.9.4"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""; ParamsVega = ""}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "AMD"
    SuffixMode = "ListGPU"
    API = "Xgminer"
    NeedsPlatformId = $true
    DevIdProp = "Type_PlatformId_Index"
    DevIdJoin = " -d "
    EnvVars = @("GPU_FORCE_64BIT_PTR=0")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "--$($_.MainAlgorithm) -d $($DeviceIDsAll) --api-port `$mport --api-listen -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-platform $($Miner_PlatformId) $($_."Params$(if ($Miner_Model -match "(gfx900|vega)") {"Vega"})")" }
}
