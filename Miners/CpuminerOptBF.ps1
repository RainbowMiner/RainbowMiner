using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\CPU-OptBF\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'aes-avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'}))"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.12-cpumineropt/cpuminer-opt-v3.8.12-bf-linux.7z"
} else {
    $Path = ".\Bin\CPU-OptBF\cpuminer-$($f=$Global:GlobalCPUInfo.Features;$(if($f.avx2 -and $f.sha -and $f.aes){'avx2-sha'}elseif($f.avx2 -and $f.aes){'avx2'}elseif($f.avx -and $f.aes){'avx'}elseif($f.sse42 -and $f.aes){'aes-sse42'}else{'sse2'})).exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v3.8.12-cpumineropt/cpuminer-opt-v3.8.12-bf-win64.zip"
}
$ManualUri = "https://github.com/bellflower2015/cpuminer-opt/releases"
$Port = "504{0:d2}"
$DevFee = 0.0
$Version = "3.8.12"

if (-not $Session.DevicesByTypes.CPU -and -not $InfoOnly) {return} # No CPU present in system

$Commands = [PSCustomObject[]]@(
    #[PSCustomObject]@{MainAlgorithm = "yespower"; Params = ""} #Yespower, CpuminerYespower faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr8"; Params = ""} #YescryptR8, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr16"; Params = ""} #YescryptR16, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr24"; Params = ""} #YescryptR24, CpuminerRplant faster
    #[PSCustomObject]@{MainAlgorithm = "yescryptr32"; Params = ""} #YescryptR32, CpuminerRplant same but also linux
    #[PSCustomObject]@{MainAlgorithm = "yespower05r16"; Params = ""} #yespowerR16 (old yenten)
    [PSCustomObject]@{MainAlgorithm = "yespowerr8"; Params = ""} #YespowerR8
    #[PSCustomObject]@{MainAlgorithm = "yespowerr16"; Params = ""} #YespowerR16, CpuminerRplant faster
    [PSCustomObject]@{MainAlgorithm = "yespowerr24"; Params = ""} #YespowerR24
    [PSCustomObject]@{MainAlgorithm = "yespowerr32"; Params = ""} #YespowerR32
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

    $DeviceParams = "$(if ($Session.Config.CPUMiningThreads){"-t $($Session.Config.CPUMiningThreads)"}) $(if ($Session.Config.CPUMiningAffinity -ne ''){"--cpu-affinity $($Session.Config.CPUMiningAffinity)"})"

    $Commands | ForEach-Object {

        $Algorithm_Norm = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm,"$($Algorithm_Norm)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-b $($Miner_Port) -a $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pools.$Algorithm_Norm.Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) -R 10 -r 4 $($DeviceParams) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm -replace '\-.*$')_HashRate".Week}
					API            = "Ccminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = if ($_.ExtendInterval -ne $null) {$_.ExtendInterval} else {2}
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