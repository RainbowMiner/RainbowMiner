using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\NVIDIA-CcminerSupr2\ccminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v2.0-ccminersupr/suprminer-2.0.7z"
$ManualUri = "https://github.com/ocminer/suprminer/releases"
$Port = "127{0:d2}"
$DevFee = 0.0
$Cuda = "9.2"

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "c11"; Params = "-N 1"} #c11
    [PSCustomObject]@{MainAlgorithm = "groestl"; Params = "-N 1"} #Groestl
    #[PSCustomObject]@{MainAlgorithm = "lyra2z"; Params = "-N 1"} #Lyra2z
    [PSCustomObject]@{MainAlgorithm = "x16r"; Params = "-N 10"; ExtendInterval = 2; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16R RavenCoin
    [PSCustomObject]@{MainAlgorithm = "x16rt"; Params = "-N 10"; ExtendInterval = 2; FaultTolerance = 0.7; HashrateDuration = "Day"} #X16RT Veil
    #[PSCustomObject]@{MainAlgorithm = "x16s"; Params = "-N 1"; FaultTolerance = 0.5} #X16S PigeonCoin    
    #[PSCustomObject]@{MainAlgorithm = "x17"; Params = "-N 1"} #x17
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
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name = $Miner_Name
                DeviceName = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path = $Path
                Arguments = "-R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -q -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
                HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate"."$(if ($_.HashrateDuration){$_.HashrateDuration}else{"Week"})"}
                API = "Ccminer"
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