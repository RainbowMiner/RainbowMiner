using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-CryptoNight\ccminer-cryptonight.exe"
$Uri = "https://github.com/KlausT/ccminer-cryptonight/releases/download/3.05/ccminer-cryptonight-305-x64-cuda92.zip"
$Port = "105{0:d2}"
$DevFee = 0.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "graft"; Params = ""; ExtendInterval = 2} #CryptoNightV8
    [PSCustomObject]@{MainAlgorithm = "monero"; Params = ""; ExtendInterval = 2} #CryptonightV7
    [PSCustomObject]@{MainAlgorithm = "stellite"; Params = ""; ExtendInterval = 2} # CryptoNightV3
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $Uri
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.Devices | Where-Object Vendor -EQ $_.Vendor | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

    $Commands | ForEach-Object {

        #fix until klaust release monero V8 variant
        $Algorithm_Norm = if ($_.MainAlgorithm -eq "monero") {Get-Algorithm "CryptoNightV7"} else {Get-Algorithm $_.MainAlgorithm}

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            if ($Pools.$Algorithm_Norm.Name -notlike "Nicehash") {
                [PSCustomObject]@{
                    Name = $Miner_Name
                    DeviceName = $Miner_Device.Name
                    DeviceModel = $Miner_Model
                    Path = $Path
                    Arguments = "-R 1 -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                    HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week}
                    API = "Wrapper"
                    Port = $Miner_Port
                    Uri = $Uri
					DevFee = $DevFee
                    FaultTolerance = $_.FaultTolerance
                    ExtendInterval = $_.ExtendInterval
                    ManualUri = $ManualUri
                }
            }
        }
    }
}