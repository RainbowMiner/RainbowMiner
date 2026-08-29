using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\NVIDIA-Lyra2z330\ccminer.exe"
$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v8.21r9-ccminerlyra2z330v3/ccminerlyra2z330v3.zip"
        Cuda = "10.0"
    }
)

$ManualUri = "https://github.com/Minerx117/ccminer8.21r9-lyra2z330/releases"
$Port = "138{0:d2}"
$DevFee = 0.0
$Version = "8.21r9"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "lyra2z330"; Params = "-i 12.5"; ExtendInterval = 2; FaultTolerance = 0.3} #Lyra2z330
)

if (-not $InfoOnly) {
    $Cuda = $null
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
        }
    }
    
    if (-not $Cuda) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    ArchNotIn = @("Other")
    HashRateMode = "DayPenalty"
    MaxRejDefault = 0.5
    MiningPriority = 2
    EmitsMaxRej = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "--no-cpu-verify -N 1 -R 1 -b `$mport -a $($_.MainAlgorithm) -d $($DeviceIDsAll) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
}
