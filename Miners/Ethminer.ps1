using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Ethash-Ethminer\ethminer.exe"
$URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.15.0/ethminer-0.15.0-Windows.zip"
$Port = "301{0:d2}"

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "ethash2gb"; MinMemGB = 2; Params = @()} #Ethash2GB
    [PSCustomObject]@{MainAlgorithm = "ethash3gb"; MinMemGB = 3; Params = @()} #Ethash3GB
    [PSCustomObject]@{MainAlgorithm = "ethash"   ; MinMemGB = 4; Params = @()} #Ethash
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices = @($Devices.NVIDIA) + @($Devices.AMD) 
if (-not $Devices -and -not $Config.InfoOnly) {return} # No GPU present in system

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Vendor = Get-DeviceVendor $_
    $Miner_Model = $_.Model

    switch($Miner_Vendor) {
        "NVIDIA" {$Miner_Deviceparams = "--cuda --cuda-devices"}
        "AMD" {$Miner_Deviceparams = "--opencl --opencl-platform $($Device | Select-Object -First 1 -ExpandProperty PlatformId) --opencl-devices"}
        Default {$Miner_Deviceparams = ""}
    }
    $Miner_Vendor = (Get-Culture).TextInfo.ToTitleCase($Miner_Vendor.ToLower())

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGB = $_.MinMemGB

        if ($Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge $MinMemGB * 1Gb})) {
            $Miner_Name = ((@($Name) + @("$($Algorithm_Norm -replace '^ethash', '')") + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-')  -replace "-+", "-"
            $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
            $DeviceIDsAll = ($Miner_Device | ForEach-Object {'{0:x}' -f ($_.Type_Vendor_Index)}) -join ' '

            $Miner_Protocol = $Pools.$Algorithm_Norm.Protocol
            if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash') {$Miner_Protocol = $Miner_Protocol -replace "stratum","stratum2"}
        
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api-port $($Miner_Port) $($Miner_Deviceparams) $($DeviceIDsAll) -P $($Miner_Protocol)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
            }
        }
    }
}
