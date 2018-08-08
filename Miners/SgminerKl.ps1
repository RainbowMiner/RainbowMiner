using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [PSCustomObject]$Stats,
    [PSCustomObject]$Config,
    [PSCustomObject]$Devices
)

$Path = ".\Bin\AMD-SgminerKl\sgminer.exe"
$Uri = "https://github.com/KL0nLutiy/sgminer-kl/releases/download/kl-1.0.5fix/sgminer-kl-1.0.5_fix-windows_x64.zip"
$ManualUri = "https://github.com/KL0nLutiy"
$Port = "402{0:d2}"

$Devices = $Devices.AMD
if (-not $Devices -or $Config.InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "aergo"; Params = "-X 256 -g 2"} #Aergo
    [PSCustomObject]@{MainAlgorithm = "blake"; Params = ""} #Blake
    [PSCustomObject]@{MainAlgorithm = "bmw"; Params = ""} #Bmw
    [PSCustomObject]@{MainAlgorithm = "echo"; Params = ""} #Echo
    [PSCustomObject]@{MainAlgorithm = "hamsi"; Params = ""} #Hamsi
    [PSCustomObject]@{MainAlgorithm = "keccak"; Params = ""} #Keccak
    [PSCustomObject]@{MainAlgorithm = "phi"; Params = "-X 256 -g 2 -w 256"} # Phi
    [PSCustomObject]@{MainAlgorithm = "skein"; Params = ""} #Skein
    [PSCustomObject]@{MainAlgorithm = "tribus"; Params = "-X 256 -g 2"} #Tribus
    [PSCustomObject]@{MainAlgorithm = "whirlpool"; Params = ""} #Whirlpool
    [PSCustomObject]@{MainAlgorithm = "xevan"; Params = "-X 256 -g 2"} #Xevan
    [PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-X 256 -g 2"} #X16S Pigeoncoin
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-X 256 -g 2"} #X16R Ravencoin
    [PSCustomObject]@{MainAlgorithm = "x17"; Params = "-X 256 -g 2"}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = $Miner_Device.Type_PlatformId_Index -join ','
    $Miner_PlatformId = $Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path       = $Path
                Arguments  = "--device $($DeviceIDsAll) --api-port $($Miner_Port) --api-listen -k $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)"
                HashRates  = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                API        = "Xgminer"
                Port       = $Miner_Port
                URI        = $Uri
                DevFee     = 1.0
                ManualUri = $ManualUri
            }
        }
    }
}