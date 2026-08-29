using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\NVIDIA-CcminerBMW512\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.2.5-ccminerbmw512/ccminerbmw512x86.7z"
$ManualUri = "https://github.com/Minerx117/ccminer-bmw512/releases"
$Port = "133{0:d2}"
$DevFee = 0.0
$Cuda = "9.1"
$Version = "2.2.5"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "bmw512"; Params = "-a bmw512"; ExtendInterval = 2} #BMW512
)

if (-not $InfoOnly) {
    if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    DevFeeZero = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
