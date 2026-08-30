using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

if ($IsLinux) {
    $Path = ".\Bin\CPU-Nheqminer\nheqminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.2-nheqminer/nheqminer-0.8.2-linux.7z"
} else {
    $Path = ".\Bin\CPU-Nheqminer\nheqminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.8.2-nheqminer/nheqminer-0.8.2-win.7z"
}
$ManualUri = "https://github.com/VerusCoin/nheqminer/releases"
$Port = "236{0:d2}"
$DevFee = 0.0
$Version = "0.8.2"

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "verus"; Params = ""; ExtendInterval = 2} #VerusHash
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "ListCPU"
    CheckSSL = $true
    CpuParams = $true
    API = "Nheq"
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-a `$mport -v -l $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)" }
}
