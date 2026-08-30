using module ..\Modules\Include.psm1

param(
    [String]$Name,
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}
if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Path = ".\Bin\NeoScrypt-Claymore\NeoScryptMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.2-claymoreneoscrypt/claymore_neoscrypt_1.2.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3012600.0"
$Port = "202{0:d2}"
$DevFee = 2.0
$Version = "1.2"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "neoscrypt"; Params = ""}
)

# $Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

Invoke-MinerFamily -Name $Name -Pools $Pools -InfoOnly $InfoOnly -Setup @{
    Vendor = "AMD"
    SuffixMode = "ListGPU"
    CheckSSL = $true
    API = "Claymore"
    DevIdHex = $true
    DevIdJoin = ""
    EnvVars = @("GPU_FORCE_64BIT_PTR=0")
    Path = $Path; ManualUri = $ManualUri; Port = $Port; DevFee = $DevFee; Version = $Version
    Uri = $Uri
    Commands = $Commands
    MakeArgs = { "-r -1 -mport -`$mport -pool $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -psw $($Pools.$Algorithm_Norm.Pass) -di $($DeviceIDsAll) $($_.Params)" }
    PerModel = { $Miner_Device = $Miner_Device_All | Where-Object {$_.Model -ne "gfx1010" -and $_.Model -notmatch "^RX[56]\d00"} }
}
