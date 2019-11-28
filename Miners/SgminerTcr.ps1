using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsLinux -and -not $IsWindows) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-SgminerTCR\sgminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.4-sgminertcr/sgminertcr-v0.1.4-linux.7z"
    $Version = "0.1.4"
} else {
    $Path = ".\Bin\AMD-SgminerTCR\sgminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.1.5-sgminertcr/sgminertcr-v0.1.5-win64.zip"
    $Version = "0.1.5"
}
$ManualUri = "https://github.com/tecracoin/sgminer/releases"
$Port = "414{0:d2}"
$DevFee = 0.0

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No AMD present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "mtp-tcr"; Params = "--kernel mtp --worksize 64 -I 20"; ParamsVega = "--kernel mtp_vega --worksize 256 -I 23"}
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
    $First = $true
    $Miner_Device = $Session.DevicesByTypes."$($_.Vendor)" | Where-Object Model -EQ $_.Model
    $Miner_Model = $_.Model

    $Commands | ForEach-Object {

        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
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
					Arguments      = "$($_."Params$(if ($Miner_Model -match "(gfx900|vega)") {"Vega"})") --device $($DeviceIDsAll) --api-port `$mport --api-listen -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --gpu-platform $($Miner_PlatformId)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Xgminer"
					Port           = $Miner_Port
					Uri            = $Uri
					FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $DevFee
					ManualUri      = $ManualUri
					EnvVars        = @("GPU_FORCE_64BIT_PTR=0","GPU_MAX_SINGLE_ALLOC_PERCENT=100")
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    }
}