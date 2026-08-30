using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

if ($IsLinux) {
    $Path = ".\Bin\NVIDIA-EWBFZcash\miner"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3.4b-ewbf/EWBF-nvidia-linux.0.3.4b.7z"
} else {
    $Path = ".\Bin\NVIDIA-EWBFZcash\miner.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.3.4b-ewbf/EWBF-nvidia-win.0.3.4b.7z"
}
$ManualUri = "https://bitcointalk.org/index.php?topic=1707546.0"
$Port = "351{0:d2}"
$DevFee = 0.0
$Cuda = "8.0"
$Version = "0.3.4b"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "Equihash";  MinMemGB = 2; Params = ""; ExcludePoolName = "Nicehash"}  #Equihash
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if (-not $InfoOnly) {
if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "Keys"
    FirstPerCmd = $true
    UseExcludePool = $true
    API = "DSTM"
    DevIdJoin = " "
    ExtendDefault = 2
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "--api 127.0.0.1:`$mport --cuda_devices $($DeviceIDsAll) --server $($Pools.$Algorithm_Norm.Host) --port $($Pool_Port) --fee 0 --eexit 1 --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"}) $($_.Params)" }
    PreKey = {
        $MinMemGB = $_.MinMemGB
        $Miner_Device = $Miner_Device_All | Where-Object {Test-VRAM $_ $MinMemGB}
    }
}
