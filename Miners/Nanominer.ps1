using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

$Path = ".\Bin\CPU-Nanominer\nanominer.exe"
$URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.1.0-nanominer/nanominer-windows-1.1.0.zip"
$ManualURI = "https://github.com/nanopool/nanominer/releases"
$Port = "534{0:d2}"
$DevFee = 3.0

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No GPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "RandomHash"; Params = ""; ExtendInterval = 2} #RandomHash/PASCcoin
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("CPU")
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

$Session.DevicesByTypes.CPU | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Device = $Session.DevicesByTypes.CPU | Where-Object Model -EQ $_.Model
    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
    $Miner_Model = $_.Model
    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
    $Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

    #$Miner_Port = 4048

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){" -cputhreads $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" -processorsaffinity $((ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity) -join ",")"})"
    
    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {

				$Arguments = [PSCustomObject]@{
                    Algo   = $_.MainAlgorithm
					Host   = $Pools.$Algorithm_Norm.Host
					Port   = $Pools.$Algorithm_Norm.Port
					SSL    = $Pools.$Algorithm_Norm.SSL
					Wallet = $Pools.$Algorithm_Norm.Wallet
                    Worker = "{workername:$($Pools.$Algorithm_Norm.Worker)}"
                    Pass   = $Pools.$Algorithm_Norm.Pass
                    Email  = $Pools.$Algorithm_Norm.Email
                    Threads= $Session.Config.CPUMiningThreads
				}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = $Arguments
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Nanominer"
					Port           = $Miner_Port
					Uri            = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
					DevFee         = $DevFee
					ManualUri      = $ManualUri
                    MiningAffinity = $Session.Config.CPUMiningAffinity
				}
			}
		}
    }
}