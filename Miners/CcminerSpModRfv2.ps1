using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows) {return}

$ManualUri = "https://github.com/sp-hash/microbitcoin/releases"
$Port = "135{0:d2}"
$Cuda = "9.2"
$DevFee = 0.0
$Version = "1.0"

if ($IsLinux) {
    #$Path = ".\Bin\NVIDIA-CcminerRfv2\ccminer"
    #$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0.2-ccminerrfv2/ccminerrfv2-1.0.2.tar.gz"
} else {
    $Path = ".\Bin\NVIDIA-CcminerSpModRfv2\ccminer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.0-rfv2spmod/rfv2spmod1.7z"
}

if (-not $Session.DevicesByTypes.NVIDIA -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "rfv2"; Params = ""; ExtendInterval = 2; MinMemGB = 4} #Rainforest2
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("NVIDIA")
        Name      = $Name
        Path      = $Path
        Port      = $Miner_Port
        Uri       = $URI
        DevFee    = $DevFee
        ManualUri = $ManualUri
        Commands  = $Commands
    }
    return
}

if (-not (Confirm-Cuda -ActualVersion $Session.Config.CUDAVersion -RequiredVersion $Cuda -Warning $Name)) {return}

$Session.DevicesByTypes.NVIDIA | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = $_.MinMemGB
        $Miner_Device = $Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGB * 1gb - 0.25gb)}
        $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
        $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
        $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

        $DeviceIDsAll   = $Miner_Device.Type_Vendor_Index -join ','

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--cpu-priority 4 -N 9 -R 1 -b $($Miner_Port) -d $($DeviceIDsAll) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User) -p $($Pools.$Algorithm_Norm.Pass) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					URI            = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					ManualUri      = $ManualUri
                    Version        = $Version
				}
			}
		}
    }
}