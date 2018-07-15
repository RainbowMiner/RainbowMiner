using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Ethash-Phoenix\PhoenixMiner.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.0c-phoenixminer/PhoenixMiner_3.0c.zip"
$ManualURI = "https://bitcointalk.org/index.php?topic=2647654.0"
$Port = "308{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""} #Ethash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

Select-Device $Devices -MinMemSize 3GB | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Vendor = Get-DeviceVendor $_
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = ($Miner_Device | % {$_.Type_PlatformId_Index+1}) -join ''

    switch($Miner_Vendor) {
        "NVIDIA" {$Miner_Deviceparams = "-nvidia"}
        "AMD" {$Miner_Deviceparams = "-amd"}
        Default {$Miner_Deviceparams = ""}
    }
    $Miner_Vendor = (Get-Culture).TextInfo.ToTitleCase($Miner_Vendor.ToLower())

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $possum    = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "-proto 4 -stales 0" } else { "-proto 1" }
        $proto     = if ( $Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp" <#temp fix#> ) { "stratum+tcp://" } else { "" }

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-rmode 0 -cdmport $($Miner_Port) -cdm 1 -coin auto -gpus $($DeviceIDsAll) -pool $($proto)$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass) $($possum) $($Miner_Deviceparams) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
                DevFee = 0.65
            }
        }
    }
}