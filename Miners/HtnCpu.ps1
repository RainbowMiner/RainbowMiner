using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux) {return}
if (-not $InfoOnly) {
    if (-not $Global:DeviceCache.DevicesByTypes.CPU) {return} # No CPU present in system
    if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.30")) {return}
}

$ManualUri = "https://htn.foztor.net/"
$Port = "237{0:d2}"
$DevFee = 1.5
$Version = "1.4.9"

if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {
    if ($Global:GlobalCPUInfo.Architecture -ne 8) {return}
    $Path = ".\Bin\CPU-Htn\hoo_cpu_arm"
    $Uri  = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.9-htm/hoo_cpu_arm-1.4.9.tar.gz"
} else {
    if (-not $Global:GlobalCPUInfo.Features.avx2 -and -not $InfoOnly) {return} # Needs AVX2
    $Path = ".\Bin\CPU-Htn\hoo_cpu"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.9-htm/hoo_cpu-1.4.9.tar.gz"
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "hoohashpepew"; MinMemGB = 2; Params = "--pepepow"; Vendor = @("CPU")} #PEPEW/HoohashPepeW
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "KeysNoGPU"
    CpuParams = $true
    UseExcludePool = $true
    ExtendDefault = 2
    InfoTypes = @("CPU","ARMCPU")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-b 127.0.0.1:`$mport -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) -q $($_.Params)" }
}
