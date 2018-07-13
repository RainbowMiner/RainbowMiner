using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\CryptoNight-SRBMiner\srbminer-cn.exe"
$Uri = "http://www.srbminer.com/downloads/SRBMiner-CN-V1-6-4.zip"
$ManualUri = "https://bitcointalk.org/index.php?topic=3167363.0"
$Port = "315{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@()
@("alloy","artocash","b2n","bittubev2","fast","lite","haven","heavy","italo","litev7","marketcash","normalv7","stellitev4") | Foreach-Object {
    $Commands += [PSCustomObject]@{MainAlgorithm = "cryptonight$($_)"; Params = ""; Type = "$_"}
}
#- Cryptonight Lite [lite]
#- Cryptonight V7 [normalv7]
#- Cryptonight Lite V7 [litev7]
#- Cryptonight Heavy [heavy]
#- Cryptonight Haven [haven]
#- Cryptonight Fast [fast]
#- Cryptonight BitTubeV2 [bittubev2]
#- Cryptonight StelliteV4 [stellitev4]
#- Cryptonight ArtoCash [artocash]
#- Cryptonight Alloy [alloy]
#- Cryptonight B2N [b2n]
#- Cryptonight MarketCash [marketcash]
#- Cryptonight Italo [italo]

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDs = Get-GPUIDs $Miner_Device

    $Commands | Where-Object {$Pools.(Get-Algorithm $_.MainAlgorithm).Protocol -eq "stratum+tcp" <#temp fix#>} | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $Miner_ConfigFileName = "$($Pools.$Algorithm_Norm.Name)_$($Algorithm_Norm)_$($Pools.$Algorithm_Norm.User)_$(@($Miner_Device.Name | Sort-Object) -join '-').txt"
        $Miner_WorkerName = [string]($Pools.$Algorithm_Norm.User -split '\.' | Select-Object -Index 1)
        if (-not $Miner_WorkerName) {$Miner_WorkerName="rainbowminer"}

        ([PSCustomObject]@{
            cryptonight_type = $_.Type
            intensity = 0
            double_threads = $true
            timeout = 10
            retry_time = 10
            api_enabled = $true
            api_port = $Miner_Port
            api_rig_name = $Miner_WorkerName
            gpu_conf = [PSCustomObject[]]@($DeviceIDs | Foreach-Object {[PSCustomObject]@{id=$_;intensity=0;worksize=8;threads=2}})
        } | ConvertTo-Json -Depth 10) | Set-Content "$(Split-Path $Path)\$($Miner_ConfigFileName)" -Force -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path      = $Path
            Arguments = "--config $($Miner_ConfigFileName) --cpool $($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --cwallet $($Pools.$Algorithm_Norm.User) --password $($Pools.$Algorithm_Norm.Pass) --disablegpuwatchdog --sendallstales $(if ($Pools.$Algorithm_Norm.SSL){'--ctls true'}) $(if ($Pools.$Algorithm_Norm.Name -eq "NiceHash"){'--cnicehash true'}) $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
            API       = "SrbMiner"
            Port      = $Miner_Port
            URI       = $Uri
            DevFee    = 0.85
        }
    }
}