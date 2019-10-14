using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\ANY-NanominerRh\nanominer"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5.3-nanominer/nanominer-linux-1.5.3.tar.gz"
} else {
    $Path = ".\Bin\ANY-NanominerRh\nanominer.exe"
    $URI = "https://github.com/RainbowMiner/miner-binaries/releases/download/v1.5.3-nanominer/nanominer-windows-1.5.3.zip"
}
$ManualURI = "https://github.com/nanopool/nanominer/releases"
$Port = "533{0:d2}"
$DevFee = 3.0
$Version = "1.5.3"

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "RandomHash"; Params = ""; NH = $true; ExtendInterval = 2; DevFee = 3.0} #RandomHash/PASCcoin
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
    $Miner_Model  = $_.Model

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){" -cputhreads $($Session.Config.CPUMiningThreads)"})$(if ($Session.Config.CPUMiningAffinity -ne ''){" -processorsaffinity $((ConvertFrom-CPUAffinity $Session.Config.CPUMiningAffinity) -join ",")"})"
    
    $Commands | ForEach-Object {
        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and ($_.NH -or $Pools.$Algorithm_Norm.Name -notmatch "Nicehash")) {
				$Pool_Port = $Pools.$Algorithm_Norm.Port
				$Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
				$Miner_Port = Get-MinerPort -MinerName $Name -DeviceName @($Miner_Device.Name) -Port $Miner_Port

                $Wallet    = if ($Pools.$Algorithm_Norm.Wallet) {$Pools.$Algorithm_Norm.Wallet} else {$Pools.$Algorithm_Norm.User}
                $PaymentId = $null
                if ($Wallet -match "^(.+?)[\.\+]([0-9a-f]{16,})") {
                    $Wallet    = $Matches[1]
                    $PaymentId = $Matches[2]
                } else {
                    $PaymentId = "0"
                }

				$Arguments = [PSCustomObject]@{
                    Algo      = $_.MainAlgorithm
					Host      = $Pools.$Algorithm_Norm.Host
					Port      = $Pools.$Algorithm_Norm.Port
					SSL       = $Pools.$Algorithm_Norm.SSL
					Wallet    = $Wallet
                    PaymentId = $PaymentId
                    Worker    = "{workername:$($Pools.$Algorithm_Norm.Worker)}"
                    Pass      = $Pools.$Algorithm_Norm.Pass
                    Email     = $Pools.$Algorithm_Norm.Email
                    Threads   = $Session.Config.CPUMiningThreads
                    Devices   = $null
				}

                $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'

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
                    Penalty        = 0
					DevFee         = $_.DevFee
					ManualUri      = $ManualUri
                    MiningAffinity = $Session.Config.CPUMiningAffinity
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = @($Algorithm_Norm -replace '\-.*')
				}
			}
		}
    }
}