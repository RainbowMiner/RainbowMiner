using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-Teamred\teamredminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.0-teamred/teamredminer-v0.6.0-linux.tgz"
} else {
    $Path = ".\Bin\AMD-Teamred\teamredminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.6.0-teamred/teamredminer-v0.6.0-win.zip"
}
$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0
$Version = "0.6.0"

if (-not $Session.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cn_conceal";       MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_haven";         MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_heavy";         MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_saber";         MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnr";              MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8";             MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_dbl";         MinMemGb = 4; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_half";        MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_rwz";         MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_trtl";        MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_upx2";        MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckarood29_grin"; MinMemGb = 8; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckatoo31_grin";  MinMemGb = 8; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "ethash";           MinMemGb = 4; Params = ""; DevFee = 0.75}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3";        MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";           MinMemGb = 2; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "mtp";              MinMemGb = 6; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "phi2";             MinMemGb = 2; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa";      MinMemGb = 2; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "x16r";             MinMemGb = 4; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rt";            MinMemGb = 2; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rv2";           MinMemGb = 2; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16s";             MinMemGb = 2; Params = ""; DevFee = 2.5}
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

if ($InfoOnly) {
    [PSCustomObject]@{
        Type      = @("AMD")
        Name      = $Name
        Path      = $Path
        Port      = $Port
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
        $First = $True
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm
        $Miner_Device = @($Device | Where-Object {$_.OpenCL.GlobalMemsize -ge ($MinMemGb * 1gb - 0.25gb)})
        $Miner_DevFee = $_.DevFee

        if ($_.MainAlgorithm -eq "ethash" -and (($Miner_Model -split '-') -notmatch "(Baffin|Ellesmere|RX\d)" | Measure-Object).Count) {
            $Miner_DevFee = 1.0
        }

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)")) {
			if ($Pools.$Algorithm_Norm.Host -and $Miner_Device) {
                if ($First) {
				    $Miner_Port = $Port -f ($Miner_Device | Select-Object -First 1 -ExpandProperty Index)            
					$Miner_Name = (@($Name) + @($Miner_Device.Name | Sort-Object) | Select-Object) -join '-'
                    $DeviceIDsAll = $Device.Type_Vendor_Index -join ','
                    $AdditionalParams = @()
                    if ($Pools.$Algorithm_Norm_0.Name -match "^bsod" -and $Algorithm_Norm_0 -eq "x16rt") {
                        $AdditionalParams += "--no_ntime_roll"
                    }
                    if ($IsLinux -and $Algorithm_Norm_0 -match "^cn") {
                        $AdditionalParams += "--allow_large_alloc"
                    }
                    $First = $False
                }

				$Pool_Port = if ($Pools.$Algorithm_Norm.Ports -ne $null -and $Pools.$Algorithm_Norm.Ports.GPU) {$Pools.$Algorithm_Norm.Ports.GPU} else {$Pools.$Algorithm_Norm.Port}

				[PSCustomObject]@{
					Name           = $Miner_Name
					DeviceName     = $Miner_Device.Name
					DeviceModel    = $Miner_Model
					Path           = $Path
					Arguments      = "-a $($_.MainAlgorithm) -d $($DeviceIDsAll) -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --api_listen=`$mport --platform=$($Miner_PlatformId) $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Session.Stats."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
					API            = "Xgminer"
					Port           = $Miner_Port
					Uri            = $Uri
                    FaultTolerance = $_.FaultTolerance
					ExtendInterval = $_.ExtendInterval
                    Penalty        = 0
					DevFee         = $Miner_DevFee
					ManualUri      = $ManualUri
                    Version        = $Version
                    PowerDraw      = 0
                    BaseName       = $Name
                    BaseAlgorithm  = $Algorithm_Norm_0
				}
			}
		}
    }
}