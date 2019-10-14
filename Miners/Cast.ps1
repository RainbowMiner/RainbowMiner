using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.71-cast/cast_xmr-vega-ubuntu_171.tar.gz"
    $Version = "1.7.1"
} else {
    $Path = ".\Bin\CryptoNight-Cast\cast_xmr-vega.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.8.0-cast/cast_xmr-vega-win64_180.zip"
    $Version = "1.8.0"
}
$Port = "306{0:d2}"
$DevFee = 1.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(    
    [PSCustomObject]@{MainAlgorithm = "cryptonightfast"; Params = "--algo=8"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightheavy"; Params = "--algo=2"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightlite"; Params = "--algo=3"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightsuperfast"; Params = "--algo=11"}
    [PSCustomObject]@{MainAlgorithm = "cryptonighttubeheavy"; Params = "--algo=5"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightturtle"; Params = "--algo=9"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7"; Params = "--algo=1"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv7lite"; Params = "--algo=4"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8fast"; Params = "--algo=6"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightv8"; Params = "--algo=10"}
    [PSCustomObject]@{MainAlgorithm = "cryptonightxhvheavy"; Params = "--algo=7"}
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
    $Devices = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm
        $MinMemGb = $_.MinMemGb
        $Params = $_.Params

        $Miner_Device = $Devices | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb) -and $_.OpenCL.Name -match "^(Ellesmere|Polaris|Vega|gfx900)"}

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port
				$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--remoteaccess --remoteport $($Miner_Port) -S $($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --opencl $($Miner_Device | Select-Object -First 1 -ExpandProperty PlatformId) -G $(($Miner_Device | ForEach-Object {'{0:x}' -f $_.Type_Vendor_Index}) -join ',') --fastjobswitch --intensity -1$(if ($Pools.$Algorithm_Norm.Name -notmatch "NiceHash") {" --nonicehash"}) $($_.Params)" 
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Cast"
					Port           = $Miner_Port
					URI            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}