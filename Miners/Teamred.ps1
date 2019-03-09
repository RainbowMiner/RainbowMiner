using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\AMD-Teamred\teamredminer.exe"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.4.0-teamred/teamredminer-v0.4.0-win.zip"
$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cnr";    MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8";   MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3"; MinMemGb = 1; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2z"; MinMemGb = 1; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "phi2";   MinMemGb = 1; Params = ""; DevFee = 3.0}
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
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Miner_PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands | ForEach-Object {        
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb)})
        $DeviceIDsAll = $Device.Type_Vendor_Index -join ','

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				[PSCustomObject]@{
					Name = $Miner_Name
					DeviceName = $Miner_Device.Name
					DeviceModel = $Miner_Model
					Path      = $Path
					Arguments = "-a $($_.MainAlgorithm) -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --api_listen=$($Miner_Port) --platform=$($Miner_PlatformId) $($_.Params)"
					HashRates = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API       = "Xgminer"
					Port      = $Miner_Port
					Uri       = $Uri
					DevFee    = $_.DevFee
					ManualUri = $ManualUri
				}
			}
		}
    }
}