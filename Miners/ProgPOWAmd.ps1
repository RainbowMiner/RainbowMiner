using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-ProgPOW\progpowminer-amd.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.16-progpowminer/progpowminer-amd-windows-0.16_final.7z"
$Port = "409{0:d2}"
$ManualURI = "https://github.com/BitcoinInterestOfficial/BitcoinInterest/releases"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "progpow"; Params = ""; ExtendInterval = 2} #ProgPOW
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
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

$Session.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ' '

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
            $Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
            [PSCustomObject]@{
                Name        = $Miner_Name
                DeviceName  = $Miner_Device.Name
                DeviceModel = $Miner_Model
                Path        = $Path
                Arguments   = "--api-port -$($Miner_Port) -P stratum$(if ($Pools.$Algorithm_Norm.SSL) {"s"})://$(Get-UrlEncode $Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {":$(Get-UrlEncode $Pools.$Algorithm_Norm.Pass)"})@$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) --opencl --opencl-platform $($Miner_Device | Select -Unique -ExpandProperty PlatformId) --opencl-devices $($DeviceIDsAll) $($_.Params)"
                HashRates   = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm)_HashRate".Week }
                API         = "Claymore"
                Port        = $Miner_Port
                Uri         = $Uri
				DevFee      = $DevFee
                ManualUri   = $ManualUri
                EnvVars     = @("GPU_FORCE_64BIT_PTR=0")
                ExtendInterval = $_.ExtendInterval
            }
        }
    }
}