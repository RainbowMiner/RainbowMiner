using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux) {return}
if ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM) {return} # No ARM binaries available
if ($Session.LibCVersion -and $Session.LibCVersion -lt (Get-Version "2.30")) {return}

$ManualUri = "https://htn.foztor.net/"
$Port = "379{0:d2}"
$DevFee = 1.5
$Version = "1.4.9"

$Path = ".\Bin\NVIDIA-Htn\hoo_gpu"
$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.4.9-htm/hoo_gpu-1.4.9.tar.gz"
        Cuda = "12.0"
    }
)

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "hoohashpepew"; MinMemGB = 2; Params = "--pepepow"; Vendor = @("NVIDIA")} #PEPEW/HoohashPepeW
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly) {
$Cuda = $null
for($i=0;$i -lt $UriCuda.Count -and -not $Cuda;$i++) {
    if (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $UriCuda[$i].Cuda -Warning $(if ($i -lt $UriCuda.Count-1) {""}else{$Name})) {
        $Uri  = $UriCuda[$i].Uri
        $Cuda = $UriCuda[$i].Cuda
    }
}

if (-not $Cuda) {return}

$Miner_EnvVars = "LD_LIBRARY_PATH=./libs"
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "KeysNoGPU"
    UseExcludePool = $true
    ExtendDefault = 2
    EnvVars = "LD_LIBRARY_PATH=./libs"
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "-b 127.0.0.1:`$mport -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$($DeviceParams) -q $($_.Params)" }
}
