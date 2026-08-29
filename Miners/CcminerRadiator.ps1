using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/xiaolin1579/radiator/releases"
$Port = "108{0:d2}"
$DevFee = 0.0
$Version = "1.0.0"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Radiator\ccminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-ccminerradiator/ccminerradiator-1.0.0-cuda116-linux.7z"
            Cuda = "11.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-ccminerradiator/ccminerradiator-1.0.0-cuda112-linux.7z"
            Cuda = "11.2"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Radiator\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-ccminerradiator/Radiator1.0.0_cuda11.6_Win64.zip"
            Cuda = "11.6"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.0-ccminerradiator/Radiator1.0.0_cuda11.2_Win64.zip"
            Cuda = "11.2"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "SHA512256d"; Params = ""; Algorithm="rad"} #SHA512256d/RXD
    [PSCustomObject]@{MainAlgorithm = "SHA256dt";   Params = ""; Algorithm="novo"} #SHA256dt/NOVO
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
    DevFeeZero = $true
    MiningPriority = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "-R 1 -b `$mport -d $($DeviceIDsAll) -a $($_.Algorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)" }
}
