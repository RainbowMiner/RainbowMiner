using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux) {return}

$Path = ".\Bin\CPU-Luk\luk-cpu"
$Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.15.12-lukminer/lukMiner-0.15.12-cpu-phi.tar.gz"
$ManualUri = "https://github.com/bellflower2015/cpuminer-opt/releases"
$Port = "537{0:d2}"
$DevFee = 1.0
$Version = "0.15.12"

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "CnAlloy"; Params = "-a xnalloy"; ExtendInterval = 2} #CnAlloy
    [PSCustomObject]@{MainAlgorithm = "CnDark"; Params = "-a xndark"; ExtendInterval = 2} #CnDark
    #[PSCustomObject]@{MainAlgorithm = "CnHalf"; Params = "-a xnmasari"; ExtendInterval = 2} #CnHalf
    [PSCustomObject]@{MainAlgorithm = "CnHaven"; Params = "-a xnhaven"; ExtendInterval = 2} #CnHaven
    [PSCustomObject]@{MainAlgorithm = "CnHeavy"; Params = "-a xnheavy"; ExtendInterval = 2} #CnHeavy
    #[PSCustomObject]@{MainAlgorithm = "CnLiteV7"; Params = "-a xnlight"; ExtendInterval = 2} #CnLiteV7
    [PSCustomObject]@{MainAlgorithm = "CnR"; Params = "-a xmr-v4r"; ExtendInterval = 2} #CnR
    #[PSCustomObject]@{MainAlgorithm = "CnTurtle"; Params = "-a xnlightv1"; ExtendInterval = 2} #CnTurtle
    [PSCustomObject]@{MainAlgorithm = "CnXTL"; Params = "-a xnstellite"; ExtendInterval = 2} #CnXTL
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

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"})"# $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--status-port $($Miner_Port) --host $($Pools.$Algorithm_Norm.Host) --port $($Pools.$Algorithm_Norm.Port) --user $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" --pass $($Pools.$Algorithm_Norm.Pass)"})$(if ($Pools.$Algorithm_Norm.Name -match "Nicehash") {" --nicehash"}) $($DeviceParams) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Luk"
					Port           = $Miner_Port
					Uri            = $Uri
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