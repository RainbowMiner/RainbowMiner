using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/tecracoin/ccminer/releases"
$Port = "127{0:d2}"
$DevFee = 0.0

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-CcminerMTP10\ccminer_linux_cuda"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda102.7z"
            Cuda = "10.2"
            Version = "1.2.10"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda100.7z"
            Cuda = "10.0"
            Version = "1.2.10"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-linux-cuda92.7z"
            Cuda = "9.2"
            Version = "1.2.10"
        }
    )
    $UseCPUAffinity = $true
} else {
    $Path = ".\Bin\NVIDIA-CcminerMTP10\ccminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2.10-ccminertcr/ccminertcr-v1.2.10-win.7z"
            Cuda = "10.2"
            Version = "1.2.10"
        }
    )
    $UseCPUAffinity = $false
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "mtp-classic"; MinMemGB = 5; Params = ""; ExtendInterval = 2; ExcludePoolName = "(MiningRigRentals|NiceHash)"} #MTP
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; MinMemGB = 5; Params = ""; ExtendInterval = 2; ExcludePoolName = "(MiningRigRentals|NiceHash)"} #MTPTcr
)

if (-not $InfoOnly) {
    $Cuda = $null
    for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
        if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
            $Uri  = $UriCuda[$i].Uri
            $Cuda = $UriCuda[$i].Cuda
            $Version = $UriCuda[$i].Version
        }
    }
    
    if (-not $Cuda) {return}
    
    if ($IsLinux) {$Path = "$($Path)$($Cuda -replace "\.")"}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "Keys"
    CheckSSL = $true
    MaxDevCount = 6
    PerEntryVRAM = $true
    ArchIn = @("Other","Pascal","Turing")
    DevFeeZero = $true
    MiningPriority = 2
    UseExcludePool = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Vars = @{ UseCPUAffinity = $UseCPUAffinity }
    Commands = $Commands
    MakeArgs = { "-R 1 -N 3 -b `$mport -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($UseCPUAffinity) {" --cpu-affinity 1"}) --no-donation $($_.Params)" }
}
