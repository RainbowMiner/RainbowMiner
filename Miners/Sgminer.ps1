using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Path = ".\Bin\AMD-NiceHash\sgminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1-sgminer/sgminer-5.6.1-nicehash-51-windows-amd64.zip"
$ManualUri = "https://github.com/nicehash/sgminer/releases"
$Port = "400{0:d2}"
$DevFee = 1.0
$Version = "5.6.1"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "groestlcoin"; Params = "--gpu-threads 2 --worksize 128 --intensity d"} #Groestl
    [PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    [PSCustomObject]@{MainAlgorithm = "lyra2rev2"; Params = "--gpu-threads 2 --worksize 128 --intensity d"} #Lyra2RE2
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = "--gpu-threads 1 --worksize 64 --intensity 15"} #NeoScrypt
    [PSCustomObject]@{MainAlgorithm = "sibcoin-mod"; Params = ""} #Sib
    [PSCustomObject]@{MainAlgorithm = "skeincoin"; Params = "--gpu-threads 2 --worksize 256 --intensity d"} #Skein
    [PSCustomObject]@{MainAlgorithm = "yescrypt"; Params = "--worksize 4 --rawintensity 256"} #Yescrypt

    # ASIC - never profitable 23/05/2018
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
    #[PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #Blakecoin
    #[PSCustomObject]@{MainAlgorithm = "cryptonight"; Params = " --gpu-threads 1 --worksize 8 --rawintensity 896"} #CryptoNight
    #[PSCustomObject]@{MainAlgorithm = "decred"; Params = ""} #Decred
    #[PSCustomObject]@{MainAlgorithm = "lbry"; Params = ""} #Lbry
    #[PSCustomObject]@{MainAlgorithm = "maxcoin"; Params = ""} #Keccak
    #[PSCustomObject]@{MainAlgorithm = "myriadcoin-groestl"; Params = " --gpu-threads 2 --worksize 64 --intensity d"} #MyriadGroestl
    #[PSCustomObject]@{MainAlgorithm = "nist5"; Params = ""} #Nist5
    #[PSCustomObject]@{MainAlgorithm = "pascal"; Params = ""} #Pascal
    #[PSCustomObject]@{MainAlgorithm = "vanilla"; Params = " --intensity d"} #BlakeVanilla
    #[PSCustomObject]@{MainAlgorithm = "bitcore"; Params = ""} #Bitcore
    #[PSCustomObject]@{MainAlgorithm = "blake2s"; Params = ""} #Blake2s
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
