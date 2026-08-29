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
    $Path = ".\Bin\CPU-Verium\cpuminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4-cpuminerverium/cpuminerverium_1.4_linux_x64_GCC7.7z"
} else {
    $Path = ".\Bin\CPU-Verium\cpuminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4-cpuminerverium/cpuminer_1.4_windows_x64_O2_GCC7$(if($Global:GlobalCPUInfo.IsRyzen){'_RYZEN'}).zip"
}
$ManualUri = "https://github.com/fireworm71/veriumMiner/releases"
$Port = "244{0:d2}"
$DevFee = 0.0
$Version = "1.4"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "scryptn2"; Params = "$(if ($Global:GlobalCPUInfo.IsRyzen) {"--ryzen"})"} #Scryptn2/Verium
)

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "ListCPU"
    CheckSSL = $true
    CpuParams = $true
    ExtendDefault = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-R 2 -r 10 -b `$mport -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)" }
}
