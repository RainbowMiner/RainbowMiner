using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\Equihash-BMiner7\bminer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v7.0.0-bminer/bminer-v7.0.0-9c7291b-amd64.zip"
$Port = "300{0:d2}"

$Devices = $Devices.NVIDIA
if (-not $Devices -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "equihash"; Params = ""; DevFee = 2.0} #" -nofee" #Equihash (fastest)
    #[PSCustomObject]@{MainAlgorithm = "ethash"; Params = ""; DevFee = 0.65} #Ethash (ethminer is faster and no dev fee)
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        switch ($Algorithm_Norm) {
            "Equihash" {$Stratum = if ($Pools.$Algorithm_Norm.SSL) {'stratum+ssl'}else {'stratum'}}
            "Ethash" {$Stratum = if ($Pools.$Algorithm_Norm.SSL) {'ethash+ssl'}else {'ethstratum'}}
        }

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-devices $($DeviceIDsAll) -api 127.0.0.1:$($Miner_Port) -uri $($Stratum)://$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.User)):$([System.Web.HttpUtility]::UrlEncode($Pools.$Algorithm_Norm.Pass))@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -watchdog=false -no-runtime-info -gpucheck=0 $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                API = "Bminer"
                Port = $Miner_Port
                URI = $Uri
                FaultTolerance = $_.FaultTolerance
                ExtendInterval = $_.ExtendInterval
                DevFee = $_.DevFee
            }
        }
    }
}