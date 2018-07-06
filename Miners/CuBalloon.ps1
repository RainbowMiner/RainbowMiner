using module ..\Include.psm1

$Path = ".\Bin\NVIDIA-CuBalloon\cuballoon.exe"
$Uri = "https://github.com/Belgarion/cuballoon/files/2143221/CuBalloon.1.0.2.Windows.zip"
$Port = "314{0:d2}"

if (-not $Devices.NVIDIA -or $Config.InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "balloon"; Params = ""} #Balloon
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$CuBalloonConfig = [PSCustomObject]@{
    GTX1050 = @(24,48)
    GTX1050ti = @(32,48)
    GTX1060 = @(64,48)
    GTX1070 = @(128,48)
    GTX1070ti = @(150,48)
    GTX1080 = @(384,48)
    GTX1080ti = @(448,48)
    default = @(128,48)
}

#$Devices | Select-Object Vendor, Model -Unique | ForEach-Object {
#    $Miner_Device = $Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
$Devices.NVIDIA | Where-Object {$_.Model -eq $Devices.FullComboModels.NVIDIA} | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Devices.NVIDIA | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

    $DeviceIDsAll = @()
    $DeviceCudaThreads = @()
    $DeviceCudaBlocks = @()

    $Miner_Device | Foreach-Object {
        $DeviceIDsAll += $_.PlatformId_Index
        $DeviceIx = if ($CuBalloonConfig."$($_.Model)") {$_.Model}else{"default"}
        $DeviceCudaThreads += $CuBalloonConfig.$DeviceIx[0]
        $DeviceCudaBlocks += $CuBalloonConfig.$DeviceIx[1]
    }

    $Commands | ForEach {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        [PSCustomObject]@{
            Name = $Miner_Name
            DeviceName = $Miner_Device.Name
            DeviceModel = $Miner_Model
            Path = $Path
            Arguments = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o stratum+tcp://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) --cuda_devices $($DeviceIDsAll -join ',') --cuda_threads $($DeviceCudaThreads -join ',') --cuda_blocks $($DeviceCudaBlocks -join ',') --cuda_sync 0 -t 0 $($_.Params)"
            HashRates = [PSCustomObject]@{$Algorithm_Norm = $Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
            API = "Ccminer"
            Port = $Miner_Port
            URI = $Uri
            FaultTolerance = $_.FaultTolerance
            ExtendInterval = $_.ExtendInterval
            DevFee = 4.0
        }
    }
}