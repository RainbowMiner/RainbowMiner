using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\NVIDIA-CcminerXaya\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.2-ccminerxaya/neoscryptxayaV02.7z"
$Cuda = "11.1.1"
$ManualUri = "https://github.com/xaya/ccminer/releases"
$Port = "145{0:d2}"
$DevFee = 0.0
$Version = "0.1"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "neoscrypt-xaya"; Params = ""; ExtendInterval=2} #NeoscryptXaya/CHI
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
    MakeArgs = { "-R 1 -b `$mport -a $($_.MainAlgorithm) -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Intensities) {" -i $($Intensities)"}) $($_.Params)" }
    PerModel = { $Intensities = @($Miner_Device | Foreach-Object {if ($_.OpenCL.GlobalMemsize -ge 2Gb) {"21"} else {"20"}}) -join ',' }
}
