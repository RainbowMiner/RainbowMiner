using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$ManualUri = "https://github.com/ocminer/suprminer-releases"
$Port = "107{0:d2}"
$DevFee = 1.0
$Version = "2.3.1"

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-Suprminer\suprminer"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3.1-suprminer/suprminer-cuda-11-3.tar.gz"
            Cuda = "11.3"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3.1-suprminer/suprminer-cuda-11-2.tar.gz"
            Cuda = "11.2"
        },
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3.1-suprminer/suprminer-cuda-9.1.tar.gz"
            Cuda = "9.1"
        }
    )
} else {
    $Path = ".\Bin\NVIDIA-Suprminer\suprminer.exe"
    $UriCuda = @(
        [PSCustomObject]@{
            Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.3.1-suprminer/suprminer-winx86_64_cuda11_1_v2.7z"
            Cuda = "11.1"
        }
    )
}

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "heavyhash"; MinMemGB = 2; Params = "-a obtc"; ExtendInterval = 2} #HeavyHash/OBTC
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly) {
$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
        if ($UriCuda[$i].Version -ne $null) {$Version = $UriCuda[$i].Version}
    }
}

if (-not $Cuda) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "Keys"
    FirstPerCmd = $true
    UseExcludePool = $true
    WinOrSingleDev = $true
    DevFeeZero = $true
    MiningPriority = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "-b `$mport -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -R 1 -q $($_.Params)" }
    PreKey = {
        $MinMemGB = $_.MinMemGB
        $Miner_Device = $Miner_Device_All | Where-Object {Test-VRAM $_ $MinMemGB}
    }
}
