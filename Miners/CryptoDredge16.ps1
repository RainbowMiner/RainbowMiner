using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -or $Session.IsVM) {return}
if (-not $Global:DeviceCache.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Path = ".\Bin\NVIDIA-CryptoDredge16\CryptoDredge.exe"
$ManualUri = "https://bitcointalk.org/index.php?topic=4807821"
$Port = "338{0:d2}"
$DevFee = 1.0
$Version = "0.16.0"
$Enable_Logfile = $false
$DeviceCapability = "5.0"

$UriCuda = @(
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16.0-cryptodredge/CryptoDredge_0.16.0_cuda_10.0_windows.zip"
        Cuda = "10.0"
    },
    [PSCustomObject]@{
        Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16.0-cryptodredge/CryptoDredge_0.16.0_cuda_9.2_windows.zip"
        Cuda = "9.2"
    }
)

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium";      MinMemGb = 1; Params = ""} #Allium
    [PSCustomObject]@{MainAlgorithm = "bitcore";     MinMemGb = 1; Params = ""} #BitCore
    #[PSCustomObject]@{MainAlgorithm = "exosis";      MinMemGb = 1; Params = ""} #Exosis (EXO is x16r)
    #[PSCustomObject]@{MainAlgorithm = "hmq1725";     MinMemGb = 1; Params = ""} #HMQ1725 (CD 0.23.0 faster)
    #[PSCustomObject]@{MainAlgorithm = "lyra2z";      MinMemGb = 1; Params = ""} #Lyra2z
    #[PSCustomObject]@{MainAlgorithm = "lyra2v3";     MinMemGb = 1; Params = ""} #Lyra2Re3 (CD 0.22.0 faster)
    [PSCustomObject]@{MainAlgorithm = "phi2";        MinMemGb = 1; Params = ""} #PHI2
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
}

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "NVIDIA"
    SuffixMode = "Keys"
    FirstPerCmd = $true
    UseExcludePool = $true
    DevFeeCmd = $true
    MiningPriority = -1
    Vars = @{ DeviceCapability = $DeviceCapability; Enable_Logfile = $Enable_Logfile }
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri; UriCuda = $UriCuda
    Commands = $Commands
    MakeArgs = { "-r 10 -R 1 -b 127.0.0.1:`$mport -d $($DeviceIDsAll) -a $($Algorithm) --no-watchdog -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"})$(if ($Enable_Logfile) {" --log log_`$mport.txt"}) $($_.Params) --no-nvml" }
    PerModel = { $Miner_Device = $Miner_Device_All | Where-Object {(-not $_.OpenCL.DeviceCapability -or (Compare-Version $_.OpenCL.DeviceCapability $DeviceCapability) -ge 0) -and $_.OpenCL.Architecture -in @("Other","Pascal","Turing")} }
    PreKey = { $Algorithm = if ($_.Algorithm) {$_.Algorithm} else {$_.MainAlgorithm} }
}
