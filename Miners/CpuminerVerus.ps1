using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if (-not $Global:DeviceCache.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Path = $null

if ($IsLinux) {
    $Path = ".\Bin\CPU-CcminerVerus\ccminer"
    if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM){
    	$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.3-ccminerverus/ccminerverus22-3.8.3cpu-arm.7z"
    }
    else{
    	$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.3-ccminerverus/ccminerverus22-3.8.3cpu-linux.7z"
    }
} else {
    $Path = ".\Bin\CPU-CcminerVerus\ccminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.3-ccminerverus/ccminerverus22-3.8.3cpu-win.7z"
}

if ($Path -eq $null) {return}

$ManualUri = "https://github.com/monkins1010/ccminer/releases"
$Port = "235{0:d2}"
$DevFee = 0.0
$Version = "3.8.3"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "verus"; Params = ""} #VerusHash
)

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "CPU"
    SuffixMode = "ListCPU"
    CheckSSL = $true
    CpuParams = $true
    ExtendDefault = 2
    InfoTypes = @("CPU","ARMCPU")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-N 1 -R 2 -r 10 -b `$mport -a $($_.MainAlgorithm) -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) $($_.Params)" }
}
