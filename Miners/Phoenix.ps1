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

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($Config.InfoOnly) {
    [PSCustomObject]@{
        Vendor = @("AMD","NVIDIA")
        Name = $Name
        Path = $Path
        Uri = $Uri
        Port = $Port
        Commands = $Commands
    }
    return
}

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model

    switch($_.Vendor) {
        "NVIDIA" {$Miner_Deviceparams = "-nvidia"}
        "AMD" {$Miner_Deviceparams = "-amd"}
        Default {$Miner_Deviceparams = ""}
    }

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1Gb})) {
            $Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"
            $DeviceIDsAll = ($Miner_Device | % {'{0:x}' -f ($_.Type_Vendor_Index + 1)}) -join ''

            $Miner_Protocol_Params = if ($Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp") {"-proto 4 -stales 0"} else {"-proto 1"}
            $Miner_Protocol        = if ($Pools.$Algorithm_Norm.Protocol -eq "stratum+tcp") {"stratum+tcp://"} else { "" }

            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-rmode 0 -cdmport $($Miner_Port) -cdm 1 -log 0 -coin auto -gpus $($DeviceIDsAll) -pool $($Miner_Protocol)$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -wal $($Pools.$Algorithm_Norm.User) -pass $($Pools.$Algorithm_Norm.Pass) $($Miner_Protocol_Params) $($Miner_Deviceparams) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $($Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week)}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
                DevFee = 0.65
                ManualUri = $ManualUri
            }
        }
    }
}