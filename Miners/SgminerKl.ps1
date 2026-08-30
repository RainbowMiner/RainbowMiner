using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Path = ".\Bin\AMD-SgminerKl\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.9-sgminerkl/sgminer-kl-1.0.9-windows.zip"
$ManualUri = "https://github.com/KL0nLutiy/sgminer-kl/releases"
$Port = "402{0:d2}"
$DevFee = 1.0
$Version = "1.0.9"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-X 256 -g 2"} #Aergo
    [PSCustomObject]@{MainAlgorithm = "c11"; Params = "-X 256 -g 2"} #C11
    [PSCustomObject]@{MainAlgorithm = "geek"; Params = "-X 256 -g 2"} #Geek
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = "-X 256 -g 2 -w 256"} # Phi
    [PSCustomObject]@{MainAlgorithm = "polytimos"; Params = "-X 256 -g 2 -w 256"} #Polytimos
    [PSCustomObject]@{MainAlgorithm = "skunk"; Params = "-X 256 -g 2 -w 256"} # Skunk
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-X 256 -g 2"} #Tribus
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-X 256 -g 2"} #Xevan
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-X 256 -g 2"} #X16S Pigeoncoin
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-X 256 -g 2"} #X16R Ravencoin
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "-X 256 -g 2"} #X17
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
