using module ..\Include.psm1

param(
    [PSCustomObject]$Pools,
    [Bool]$InfoOnly
)

if (-not $IsWindows -and -not $IsLinux) {return}

if ($IsLinux) {
    $Path = ".\Bin\AMD-Teamred\teamredminer"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.7.3-teamred/teamredminer-v0.7.3-linux.tgz"
} else {
    $Path = ".\Bin\AMD-Teamred\teamredminer.exe"
    $Uri = "https://github.com/RainbowMiner/miner-binaries/releases/download/v0.7.3-teamred/teamredminer-v0.7.3-win.zip"
}
$Port = "409{0:d2}"
$ManualUri = "https://bitcointalk.org/index.php?topic=5059817.0"
$DevFee = 3.0
$Version = "0.7.3"

if (-not $Global:DeviceCache.DevicesByTypes.AMD -and -not $InfoOnly) {return} # No NVIDIA present in system

$Commands = [PSCustomObject[]]@(
    [PSCustomObject]@{MainAlgorithm = "cn_conceal";       MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_haven";         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_heavy";         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cn_saber";         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnr";              MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8";             MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_dbl";         MinMemGb = 3.3; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_half";        MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_rwz";         MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_trtl";        MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cnv8_upx2";        MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckarood29_grin"; MinMemGb = 6;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "cuckatoo31_grin";  MinMemGb = 8;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "ethash";           MinMemGb = 3.3; Params = ""; DevFee = 0.75}
    [PSCustomObject]@{MainAlgorithm = "kawpow";           MinMemGb = 3;   Params = ""; DevFee = 2.0}
    [PSCustomObject]@{MainAlgorithm = "lyra2rev3";        MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "lyra2z";           MinMemGb = 1.5; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "mtp";              MinMemGb = 5;   Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "phi2";             MinMemGb = 1.5; Params = ""; DevFee = 3.0}
    [PSCustomObject]@{MainAlgorithm = "trtl_chukwa";      MinMemGb = 1.5; Params = ""; DevFee = 2.5}
    [PSCustomObject]@{MainAlgorithm = "x16r";             MinMemGb = 3.3; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rt";            MinMemGb = 1.5; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16rv2";           MinMemGb = 1.5; Params = ""; DevFee = 2.5; ExtendInterval = 2}
    [PSCustomObject]@{MainAlgorithm = "x16s";             MinMemGb = 1.5; Params = ""; DevFee = 2.5}
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

$Global:DeviceCache.DevicesByTypes.AMD | Select-Object Vendor, Model -Unique | ForEach-Object {
    $Miner_Model = $_.Model
    $Device = $Global:DeviceCache.DevicesByTypes."$($_.Vendor)".Where({$_.Model -eq $Miner_Model})

    $Miner_PlatformId = $Device | Select -Property Platformid -Unique -ExpandProperty PlatformId

    $Commands.ForEach({
        $First = $True
        $Algorithm_Norm_0 = Get-Algorithm $_.MainAlgorithm

        $MinMemGB = if ($Algorithm_Norm_0 -match "^(Ethash|KawPow|ProgPow)") {Get-EthDAGSize $Pools.$Algorithm_Norm_0.CoinSymbol} else {$_.MinMemGB}

        $Miner_Device = $Device | Where-Object {Test-VRAM $_ $MinMemGB}

        $Miner_DevFee = $_.DevFee

        if ($_.MainAlgorithm -eq "ethash" -and (($Miner_Model -split '-') -notmatch "(Baffin|Ellesmere|RX\d)" | Measure-Object).Count) {
            $Miner_DevFee = 1.0
        }

		foreach($Algorithm_Norm in @($Algorithm_Norm_0,"$($Algorithm_Norm_0)-$($Miner_Model)","$($Algorithm_Norm_0)-GPU")) {
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
					Arguments      = "-a $($_.MainAlgorithm) -d $($DeviceIDsAll) --opencl_order -o $($Pools.$Algorithm_Norm.Protocol)://$($Pools.$Algorithm_Norm.Host):$($Pool_Port) -u $($Pools.$Algorithm_Norm.User)$(if ($Pools.$Algorithm_Norm.Pass) {" -p $($Pools.$Algorithm_Norm.Pass)"}) --api_listen=`$mport --platform=$($Miner_PlatformId) $(if ($AdditionalParams.Count) {$AdditionalParams -join " "}) $($_.Params)"
					HashRates      = [PSCustomObject]@{$Algorithm_Norm = $Global:StatsCache."$($Miner_Name)_$($Algorithm_Norm_0)_HashRate".Week}
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
    })
}