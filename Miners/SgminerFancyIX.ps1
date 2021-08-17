using module ..\Modules\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

$Port = "409{0:d2}"
$ManualUri = "https://github.com/fancyIX/sgminer-phi2-branch/releases"
$DevFee = 0.0
$Version = "v0.7.5"

if ($IsLinux) {
    $Path = ".\Bin\AMD-FancyIX\sgminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.7.5-fancyix/sgminer-fancyIX-linux-amd64-0.7.5.tar.gz"
} else {
    $Path = ".\Bin\AMD-FancyIX\sgminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.7.5-fancyix/sgminer-fancyIX-win64-0.7.5.zip"
}

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "allium";         Params = "--gpu-threads 1 --worksize 256 -I 22 --difficulty-multiplier 0.5"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "allium_navi";    Params = "--gpu-threads 1 --worksize 256 -I 22 --difficulty-multiplier 0.5"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "argon2d";        Params = "--gpu-threads 2 --worksize 64"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "groestlcoin";    Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "groestlcoin_navi"; Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "lyra2v3";        Params = "--gpu-threads 1 --worksize 256 -I 24"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";         Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "lyra2z_navi";    Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "lyra2zz";        Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "mtp";            Params = "-I 20"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "neoscrypt";      Params = "--gpu-threads 1 --worksize 256 -I 17"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "neoscrypt_navi"; Params = "--gpu-threads 1 --worksize 256 -I 17"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "neoscrypt-xaja"; Params = "--gpu-threads 1 --worksize 256 -I 17"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "neoscrypt-xaja_navi"; Params = "--gpu-threads 1 --worksize 256 -I 17"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "phi2";           Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "phi2_navi";      Params = "--gpu-threads 1 --worksize 256 -I 22"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "yescrypt";       Params = "--gpu-threads 1 --worksize 256 -I 20"; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "x22i";           Params = "--gpu-threads 2 --worksize 256 -I 22"; ExtendInterval = 2; ExcludePoolName = "^Nicehash"}
    [PSCustomObject]@{MainAlgorithm = "x25x";           Params = "--gpu-threads 4 --worksize 256 -I 22"; ExtendInterval = 2; ExcludePoolName = "^Nicehash"}
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
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Commands.ForEach({

        $MainAlgorithm = $_.MainAlgorithm -replace "_navi"

        $Algorithm_Norm_0 = Get-Algorithm $MainAlgorithm

        $Miner_Device = $Device | Where-Object {($_.Model -notmatch "^RX[56]\d\d\d" -and $MainAlgorithm -eq $_.MainAlgorithm) -or ($_.Model -match "^RX[56]\d\d\d" -and $MainAlgorithm -ne $_.MainAlgorithm)}

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device -and (-not $_.ExcludePoolName -or $Pools.$Algorithm_Norm.Name -notmatch $_.ExcludePoolName)) {
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
                    Benchmarked    = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Benchmarked
                    LogFile        = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".LogFile
				}
			}
		}
    })
}