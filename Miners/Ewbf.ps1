using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\Equihash-EWBF\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-ewbf/EWBF_Equihash_miner_v0.6.tar.gz"
} else {
    $Path = ".\Bin\Equihash-EWBF\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6-ewbf/EWBF.Equihash.miner.v0.6.zip"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=4466962.0"
$Port = "311{0:d2}"
$DevFee = 0.0
$Cuda = "8.0"
$Version = "0.6"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash965";  MinMemGB = 2.5; Params = "--algo 96_5"; ExcludePoolName = "Nicehash"}  #Equihash 96,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1445"; MinMemGB = 2; Params = "--algo 144_5"; ExcludePoolName = "Nicehash"} #Equihash 144,5
    [PSCustomObject]@{MainAlgorithm = "Equihash1927"; MinMemGB = 2.5; Params = "--algo 192_7"; ExcludePoolName = "Nicehash"} #Equihash 192,7
    [PSCustomObject]@{MainAlgorithm = "Equihash2109"; MinMemGB = 0.5; Params = "--algo 210_9"; ExcludePoolName = "Nicehash"} #Equihash 210,9 (beta)
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly) {
if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "Keys"
    FirstPerCmd = $true
    UseExcludePool = $true
    API = "DSTM"
    DevIdJoin = " "
    ExtendDefault = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "--api 127.0.0.1:`$mport --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($Algorithm_Norm -match "^Equihash") {" --pers $(Get-EquihashCoinPers $Pools.$Algorithm_Norm.CoinSymbol -Default "auto")"}) $($_.Params)" }
    PreKey = {
        $MinMemGB = $_.MinMemGB
        $Miner_Device = $Miner_Device_All | Where-Object {Test-VRAM $_ $MinMemGB}
    }
}
