using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Ethash-Ethminer\ethminer.exe"
$URI = "https://github.com/ethereum-mining/ethminer/releases/download/v0.15.0rc2/ethminer-0.15.0rc2-Windows.zip"
$Port = "301{0:d2}"

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

    switch($Miner_Vendor) {
        "NVIDIA" {$Miner_Deviceparams = "--cuda-devices $($Miner_Device.Type_PlatformId_Index -join ' ') --cuda"}
        "AMD" {$Miner_Deviceparams = "--opencl-devices $($Miner_Device.Type_PlatformId_Index -join ' ') --opencl --opencl-platform $($Miner_Device | select -Property Platformid -Unique -ExpandProperty PlatformId)"}
        Default {$Miner_Deviceparams = ""}
    }
    $Miner_Vendor = (Get-Culture).TextInfo.ToTitleCase($Miner_Vendor.ToLower())

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $Miner_Protocol = $Pools.$Algorithm_Norm.Protocol -replace "stratum","stratum$(if ($Pools.$Algorithm_Norm.Name -eq 'NiceHash'){2})"       
        
        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "--api-port $($Miner_Port) $($Miner_Deviceparams) -P $($Miner_Protocol)://$($Pools.$Algorithm_Norm.User):$($Pools.$Algorithm_Norm.Pass)@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API = "Claymore"
                Port = $Miner_Port
                URI = $Uri
            }
        }
    }
}
