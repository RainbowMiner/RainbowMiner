using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\NVIDIA-Xevan\ccminer_x86.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.3-ccminerxevan/ccminerxevan_1.3.7z"
$Port = "118{0:d2}"
$DevFee = 0.0
$Cuda = "9.0"
$Version = "1.3"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"} #c11
    #[PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "lyra2v2"; Params = "-N 1"} #Lyra2RE2 (alexis78 is faster)
    #[PSCustomObject]@{MainAlgorithm = "skein"; Params = "-N 1"} #Skein
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-N 1 -i 21"} #Xevan

    # ASIC - never profitable 12/05/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blakecoin"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "myr-gr"; Params = ""} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "qubit"; Params = ""} #Qubit
    #[PSCustomObject]@{MainAlgorithm = "quark"; Params = ""} #Quark
    #[PSCustomObject]@{MainAlgorithm = "x12"; Params = ""} #X12
    #[PSCustomObject]@{MainAlgorithm = "x14"; Params = ""} #X14
)

if (-not $InfoOnly) {
    if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
