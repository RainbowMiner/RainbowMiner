using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-FancyIX\sgminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1.3.b6a-fancyix/sgminer-phi2-fancyIX-linux-amd64-0.6.0.1.zip"
} else {
    $Path = ".\Bin\AMD-FancyIX\sgminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v5.6.1.3.b6a-fancyix/sgminer-phi2-fancyIX-win64-0.6.0.1.zip"
}
$Port = "409{0:d2}"
$ManualUri = "https://github.com/fancyIX/sgminer-phi2-branch/releases"
$DevFee = 0.0
$Version = "5.6.1.3-beta6a"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium";  Params = "--gpu-threads 1 --worksize 256 -I 22"}
    [PSCustomObject]@{MainAlgorithm = "argon2d"; Params = "--gpu-threads 2 --worksize 64"}
    [PSCustomObject]@{MainAlgorithm = "lyra2v3"; Params = "--gpu-threads 1 --worksize 256 -I 24"}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";  Params = "--gpu-threads 1 --worksize 256 -I 22"}
    [PSCustomObject]@{MainAlgorithm = "lyra2zz"; Params = "--gpu-threads 1 --worksize 256 -I 22"}
    [PSCustomObject]@{MainAlgorithm = "mtp";     Params = "-I 20"}
    [PSCustomObject]@{MainAlgorithm = "phi2";    Params = "--gpu-threads 1 --worksize 256 -I 22"}
    [PSCustomObject]@{MainAlgorithm = "x22i";    Params = "--gpu-threads 2 --worksize 256 -I 22"; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x25x";    Params = "--gpu-threads 4 --worksize 256 -I 22"; ExtendInterval = 2}
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

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $First = $true
    $Miner_Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Pools.$Algorithm_Norm.Name -notmatch "Nicehash" -and $Miner_Device) {
                if ($First) {
                    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)
                    $Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Miner_Device.Type_Vendor_Index -join ','
                    $Miner_PlatformId = $Miner_Device | Select -Property Platformid -Unique -ExpandProperty PlatformId
                    $First = $false
                }
				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}
				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "--device $($DeviceIDsAll) --api-port `$mport --api-listen -k $($_.MainAlgorithm) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --text-only --gpu-platform $($Miner_PlatformId) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Xgminer"
					Port           = $Miner_Port
					Uri            = $Uri
					DevFee         = $DevFee
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					ManualUri      = $ManualUri
					EnvVars        = @("GPU_FORCE_64BIT_PTR=0")
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    }
}