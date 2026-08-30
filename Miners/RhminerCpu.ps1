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
    $Path = ".\Bin\CPU-RHminer\rhminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-rhminer/rhminer.2.3.Linux.CPU.zip"
} else {
    $Path = ".\Bin\CPU-RHminer\rhminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3-rhminer/rhminer.2.3.Windows.CPU.zip"
}
$ManualUri = "https://github.com/polyminer1/rhminer/releases"
$Port = "131{0:d2}"
$DevFee = 1.0
$Version = "2.3"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "randomhash2"; Params = ""; ExtendInterval = 2} #RandomHash/PASCcoin
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "ListCPU"
    CpuParams = $true
    API = "Claymore"
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-apiport `$mport -s $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -su $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -pw $($Pools.$Algorithm_Norm.Pass)"}) -cpu$($DeviceParams) $($_.Params)" }
    PreKey = { $DeviceParams = "$(if ($CPUThreads){" -cputhreads $CPUThreads"})$(if ($CPUAffinity){" -processorsaffinity $((ConvertFrom-CPUAffinity $CPUAffinity) -join ",")"})" }
}
