using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}
if ($IsLinux -and ($Global:GlobalCPUInfo.Vendor -eq "ARM" -or $Global:GlobalCPUInfo.Features.ARM)) {return} # No ARM binaries available
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

if ($IsLinux) {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.71-cast/cast_xmr-vega-ubuntu_171.tar.gz"
    $Version = "1.7.1"
} else {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.8.0-cast/cast_xmr-vega-win64_180.zip"
    $Version = "1.8.0"
}
$Port = "306{0:d2}"
$DevFee = 1.0

$Commands = [PSCustomObject[]]@(    
    [PSCustomObject]@{MainAlgorithm = "cryptonightfast"; Params = "--algo=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightheavy"; Params = "--algo=2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightlite"; Params = "--algo=3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightsuperfast"; Params = "--algo=11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonighttubeheavy"; Params = "--algo=5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightturtle"; Params = "--algo=9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = "--algo=1"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7lite"; Params = "--algo=4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8fast"; Params = "--algo=6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8"; Params = "--algo=10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightxhvheavy"; Params = "--algo=7"}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "AMD"
    SuffixMode = "ListGPU"
    FirstPerCmd = $true
    API = "Cast"
    NeedsPlatformId = $true
    DevIdProp = "Type_PlatformId_Index"
    DevIdHex = $true
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "--remoteaccess --remoteport `$mport -S $($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --opencl $($PlatformId) -G $($DeviceIDsAll) --fastjobswitch --intensity -1$(if ($Pools.$Algorithm_Norm.Host -notmatch "NiceHash") {" --nonicehash"}) $($_.Params)" }
    PreKey = {
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params
        $Miner_Device = $Miner_Device_All | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb) -and $_.OpenCL.Name -match "^(Ellesmere|Polaris|Vega|gfx900)"}
    }
}
