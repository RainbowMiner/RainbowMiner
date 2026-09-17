using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/tpfuemp/ccminer-tpfuemp/releases"
$Port = "147{0:d2}"
$DevFee = 0.0
$Cuda = "11.8"
$Version = "2026.09"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerTpfuemp\ccminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2026.09-ccminertpfuemp/ccminer-tpfuemp-2026.09-linux-x64.tar.gz"
} else {
    $Path = ".\Bin\NVIDIA-CcminerTpfuemp\ccminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2026.09-ccminertpfuemp/ccminer-tpfuemp-2026.09-windows-x64.zip"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium"; Params = "-a allium"; ExtendInterval = 2} #Allium/GRLC
    [PSCustomObject]@{MainAlgorithm = "argon2d1000"; Params = "-a argon2d1000"; ExtendInterval = 2} #Argon2D1000/0DYNC
    [PSCustomObject]@{MainAlgorithm = "argon2d16000"; Params = "-a argon2d16000"; ExtendInterval = 2} #Argon2d16000/ADOT
    [PSCustomObject]@{MainAlgorithm = "balloon"; Params = "-a balloon"; ExtendInterval = 2} #Balloon/DEFT
    [PSCustomObject]@{MainAlgorithm = "blake2s"; Params = "-a blake2s"; ExtendInterval = 2} #Blake2s/KDA
    [PSCustomObject]@{MainAlgorithm = "blake3decred"; Params = "-a decred"; ExtendInterval = 2} #Blake3Decred/DCR
    [PSCustomObject]@{MainAlgorithm = "curvehash"; Params = "-a curvehash"; ExtendInterval = 2} #CurveHash/CURVE
    [PSCustomObject]@{MainAlgorithm = "evohash"; Params = "-a evohash"; ExtendInterval = 2} #Evohash/EVOAI
    [PSCustomObject]@{MainAlgorithm = "hoohashpepew"; Params = "-a hoohash"; ExtendInterval = 2} #HoohashPepeW/PEPEW
    [PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = "-a lyra2v2"; ExtendInterval = 2} #Lyra2RE2/ABS
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = "-a lyra2z330"; ExtendInterval = 2} #Lyra2z330/GXX
    [PSCustomObject]@{MainAlgorithm = "neoscryptxaya"; Params = "-a neoscrypt-xaya"; ExtendInterval = 2} #NeoScryptXaya/CHI
    [PSCustomObject]@{MainAlgorithm = "odocrypt"; Params = "-a odocrypt"; ExtendInterval = 2} #Odocrypt/DGB
    [PSCustomObject]@{MainAlgorithm = "power2b"; Params = "-a power2b"; ExtendInterval = 2} #Yespower2b/MBC
    [PSCustomObject]@{MainAlgorithm = "rinhash"; Params = "-a rinhash"; ExtendInterval = 2} #Rinhash/RIN
    [PSCustomObject]@{MainAlgorithm = "sha3t"; Params = "-a sha3t"; ExtendInterval = 2} #SHA3t/BC3
    [PSCustomObject]@{MainAlgorithm = "skydoge"; Params = "-a skydoge"; ExtendInterval = 2} #SkyDoge/SKYDOGE
    [PSCustomObject]@{MainAlgorithm = "soterg"; Params = "-a soterg"; ExtendInterval = 2} #SoterG/SOTER
    [PSCustomObject]@{MainAlgorithm = "whirlpoolx2"; Params = "-a whirlpoolx2"; ExtendInterval = 2} #WhirlpoolX2/CAP
    [PSCustomObject]@{MainAlgorithm = "x16rt"; Params = "-a x16rt"; ExtendInterval = 2} #X16rt/GIN
    [PSCustomObject]@{MainAlgorithm = "x25x"; Params = "-a x25x"; ExtendInterval = 2} #X25x/SIN
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = "-a yescrypt"; ExtendInterval = 2} #Yescrypt/BSTY
    [PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = "-a yescryptr8"; ExtendInterval = 2} #YescryptR8/ZNY
    [PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = "-a yescryptr16"; ExtendInterval = 2} #YescryptR16/GOLD
    [PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = "-a yescryptr32"; ExtendInterval = 2} #YescryptR32/LBTC
    [PSCustomObject]@{MainAlgorithm = "yespower"; Params = "-a yespower"; ExtendInterval = 2} #Yespower/BELL
    [PSCustomObject]@{MainAlgorithm = "yespoweradvc"; Params = "-a yespower --yespower-param 2048,32 --yespower-key `"Let the quest begin`""; ExtendInterval = 2} #YespowerADVC/ADVC
    [PSCustomObject]@{MainAlgorithm = "yespowerarwn"; Params = "-a yespowerarwn"; ExtendInterval = 2} #YespowerARWN/ARWN
    [PSCustomObject]@{MainAlgorithm = "yespoweric"; Params = "-a yespoweric"; ExtendInterval = 2} #YespowerIC/ISO
    [PSCustomObject]@{MainAlgorithm = "yespoweriots"; Params = "-a yespoweriots"; ExtendInterval = 2} #YespowerIOTS/IOTS
    [PSCustomObject]@{MainAlgorithm = "yespowerlitb"; Params = "-a yespowerlitb"; ExtendInterval = 2} #YespowerLITB/LITB
    [PSCustomObject]@{MainAlgorithm = "yespowerltncg"; Params = "-a yespowerltncg"; ExtendInterval = 2} #YespowerLTNCG/LTNCG
    [PSCustomObject]@{MainAlgorithm = "yespowermgpc"; Params = "-a yespowermgpc"; ExtendInterval = 2} #YespowerMGPC/MGPC
    [PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = "-a yespowerr16"; ExtendInterval = 2} #YespowerR16/YTN
    [PSCustomObject]@{MainAlgorithm = "yespowersugar"; Params = "-a yespowersugar"; ExtendInterval = 2} #YespowerSUGAR/SUGAR
    [PSCustomObject]@{MainAlgorithm = "yespowertide"; Params = "-a yespowertide"; ExtendInterval = 2} #YespowerTIDE/TDC
    [PSCustomObject]@{MainAlgorithm = "yespowerurx"; Params = "-a yespowerurx"; ExtendInterval = 2} #YespowerURX/URX
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
