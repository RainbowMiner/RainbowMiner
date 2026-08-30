using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Path = ".\Bin\AMD-SgminerDyn\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-sgminerdyn/sgminer-dyn-1.0.0-windows-x64.zip"
$ManualUri = "https://github.com/duality-solutions/Dynamic-GPU-Miner-AMD/releases"
$Port = "410{0:d2}"
$DevFee = 0.0
$Version = "1.0.0"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "argon2d-dyn"; Params = "-k argon2d"}
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
    MakeArgs = { "--device $($DeviceIDsAll) --api-port `$mport --api-listen -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)" }
}
